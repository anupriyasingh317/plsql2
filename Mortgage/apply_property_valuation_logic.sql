CREATE OR REPLACE PROCEDURE apply_property_valuation_logic AS
    v_invalid_count NUMBER := 0;
    v_dummy NUMBER;  -- Variable to hold result of SELECT INTO check
    v_foreclosure_status VARCHAR2(20); -- Variable to hold foreclosure status for the loan
BEGIN
    FOR loan_rec IN (
        SELECT Loan_ID, Property_Valuation_Method, Foreclosure_Status
        FROM Loan
        WHERE Origination_Date > TO_DATE('01-JAN-2020', 'DD-MON-YYYY')
          AND Compliance_Flag = 'Y'
          AND (Review_Date IS NULL OR Review_Date <= SYSDATE)
    ) LOOP
        -- Store foreclosure status for the loan
        v_foreclosure_status := loan_rec.Foreclosure_Status;

        -- Apply business logic based on the Property_Valuation_Method code
        CASE loan_rec.Property_Valuation_Method
            WHEN 'A' THEN
                -- Appraisal (Code A): Check for appraisal documentation
                BEGIN
                    SELECT 1 INTO v_dummy 
                    FROM Appraisal_Documents 
                    WHERE Loan_ID = loan_rec.Loan_ID;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO Loan_Validation_Errors (
                            Loan_ID, Error_Type, Error_Severity, Field_Name, 
                            Validation_Rule, Error_Message, User_Action_Required, Error_Date
                        ) VALUES (
                            loan_rec.Loan_ID, 'Compliance', 'Critical', 'Appraisal Document',
                            'Appraisal document must be provided for loans with Appraisal method',
                            'Missing appraisal document', 'Y', SYSDATE
                        );
                        v_invalid_count := v_invalid_count + 1;
                END;

            WHEN 'C' THEN
                -- Appraisal Waiver plus Property Data Collection – Condition (Code C)
                BEGIN
                    SELECT 1 INTO v_dummy 
                    FROM Property_Data_Collection 
                    WHERE Loan_ID = loan_rec.Loan_ID;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO Loan_Validation_Errors (
                            Loan_ID, Error_Type, Error_Severity, Field_Name, 
                            Validation_Rule, Error_Message, User_Action_Required, Error_Date
                        ) VALUES (
                            loan_rec.Loan_ID, 'Compliance', 'Major', 'Property Data Collection',
                            'Data collection must meet GSE requirements for condition check',
                            'Missing property data collection for Condition waiver', 'Y', SYSDATE
                        );
                        v_invalid_count := v_invalid_count + 1;
                END;

            WHEN 'P' THEN
                -- Appraisal Waiver plus Property Data Collection – Value (Code P)
                BEGIN
                    SELECT 1 INTO v_dummy 
                    FROM Property_Data_Collection 
                    WHERE Loan_ID = loan_rec.Loan_ID;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO Loan_Validation_Errors (
                            Loan_ID, Error_Type, Error_Severity, Field_Name, 
                            Validation_Rule, Error_Message, User_Action_Required, Error_Date
                        ) VALUES (
                            loan_rec.Loan_ID, 'Compliance', 'Critical', 'Property Data Collection',
                            'AVM validation is required for loans with Value waiver',
                            'Missing property data collection with AVM validation for Value waiver', 'Y', SYSDATE
                        );
                        v_invalid_count := v_invalid_count + 1;
                END;

            WHEN 'R' THEN
                -- GSE Targeted Refinance Programs (Code R): Automatically set as eligible for refinance
                UPDATE Loan
                SET Eligibility_Status = 'GSE_REF_ELIG'
                WHERE Loan_ID = loan_rec.Loan_ID;

            WHEN 'W' THEN
                -- Appraisal Waiver (Code W): Mark as compliant with waiver guidelines
                BEGIN
                    SELECT 1 INTO v_dummy 
                    FROM Waiver_Approval 
                    WHERE Loan_ID = loan_rec.Loan_ID;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO Loan_Validation_Errors (
                            Loan_ID, Error_Type, Error_Severity, Field_Name, 
                            Validation_Rule, Error_Message, User_Action_Required, Error_Date
                        ) VALUES (
                            loan_rec.Loan_ID, 'Compliance', 'Minor', 'Waiver Approval',
                            'Waiver approval must be documented for Appraisal Waiver method',
                            'Missing waiver approval document', 'N', SYSDATE
                        );
                        v_invalid_count := v_invalid_count + 1;
                END;

            WHEN 'O' THEN
                -- Other (Code O): Flag for manual review
                INSERT INTO Loan_Validation_Errors (
                    Loan_ID, Error_Type, Error_Severity, Field_Name, 
                    Validation_Rule, Error_Message, User_Action_Required, Error_Date
                ) VALUES (
                    loan_rec.Loan_ID, 'Compliance', 'Warning', 'Property_Valuation_Method',
                    'Manual review is required for unspecified valuation methods',
                    'Other valuation method flagged for manual review', 'Y', SYSDATE
                );
                v_invalid_count := v_invalid_count + 1;

            ELSE
                -- Log an error if the Property_Valuation_Method is invalid or missing
                INSERT INTO Loan_Validation_Errors (
                    Loan_ID, Error_Type, Error_Severity, Field_Name, 
                    Validation_Rule, Error_Message, User_Action_Required, Error_Date
                ) VALUES (
                    loan_rec.Loan_ID, 'Data Validation', 'Critical', 'Property_Valuation_Method',
                    'Must be A, C, P, R, W, or O', 
                    'Invalid property valuation method', 'Y', SYSDATE
                );
                v_invalid_count := v_invalid_count + 1;
        END CASE;

        -- Additional foreclosure-specific validation
        IF v_foreclosure_status = 'Active' THEN
            BEGIN
                SELECT 1 INTO v_dummy
                FROM Foreclosure_Costs
                WHERE Loan_ID = loan_rec.Loan_ID
                  AND Cost_Type = 'Appraisal Fee';

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    INSERT INTO Loan_Validation_Errors (
                        Loan_ID, Error_Type, Error_Severity, Field_Name, 
                        Validation_Rule, Error_Message, User_Action_Required, Error_Date
                    ) VALUES (
                        loan_rec.Loan_ID, 'Foreclosure', 'Critical', 'Appraisal Fee',
                        'Foreclosure process requires appraisal fee in Foreclosure_Costs table',
                        'Missing appraisal fee in foreclosure costs', 'Y', SYSDATE
                    );
                    v_invalid_count := v_invalid_count + 1;
            END;
        END IF;
    END LOOP;

    -- Output the total invalid records for review
    DBMS_OUTPUT.PUT_LINE('Total invalid Property Valuation Method entries found: ' || v_invalid_count);
END apply_property_valuation_logic;
/
