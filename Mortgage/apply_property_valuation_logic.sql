CREATE OR REPLACE PROCEDURE apply_property_valuation_logic AS
    v_invalid_count NUMBER := 0;
    v_dummy NUMBER;  -- Variable to hold result of SELECT INTO check
    v_credit_score Loan.Borrower_Credit_Score%TYPE;
    v_income_status Loan.Income_Documentation_Status%TYPE;
    v_min_credit_score NUMBER := 680;  -- Minimum credit score required for GSE Targeted Refinance
BEGIN
    FOR loan_rec IN (
        SELECT Loan_ID, Property_Valuation_Method, Borrower_Credit_Score, Income_Documentation_Status
        FROM Loan
        WHERE Property_Valuation_Method = 'R'
    ) LOOP
        -- Step 1: Validate Income Documentation
        IF loan_rec.Income_Documentation_Status <> 'Verified' THEN
            INSERT INTO Loan_Validation_Errors (
                Loan_ID, Error_Type, Error_Severity, Field_Name, 
                Validation_Rule, Error_Message, User_Action_Required, Error_Date
            ) VALUES (
                loan_rec.Loan_ID, 'GSE Refinance Compliance', 'Critical', 'Income_Documentation_Status',
                'Income must be verified for GSE Targeted Refinance eligibility',
                'Loan income documentation is not verified', 'Y', SYSDATE
            );
            v_invalid_count := v_invalid_count + 1;
            CONTINUE;  -- Skip marking eligibility if validation fails
        END IF;

        -- Step 2: Validate Borrower Credit Score
        IF loan_rec.Borrower_Credit_Score < v_min_credit_score THEN
            INSERT INTO Loan_Validation_Errors (
                Loan_ID, Error_Type, Error_Severity, Field_Name, 
                Validation_Rule, Error_Message, User_Action_Required, Error_Date
            ) VALUES (
                loan_rec.Loan_ID, 'GSE Refinance Compliance', 'Critical', 'Borrower_Credit_Score',
                'Credit score must be greater than ' || v_min_credit_score,
                'Borrower credit score below required threshold for GSE eligibility', 'Y', SYSDATE
            );
            v_invalid_count := v_invalid_count + 1;
            CONTINUE;  -- Skip marking eligibility if validation fails
        END IF;

        -- Step 3: Check for required refinance documents
        BEGIN
            SELECT 1 INTO v_dummy
            FROM Refinance_Documents
            WHERE Loan_ID = loan_rec.Loan_ID;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO Loan_Validation_Errors (
                    Loan_ID, Error_Type, Error_Severity, Field_Name, 
                    Validation_Rule, Error_Message, User_Action_Required, Error_Date
                ) VALUES (
                    loan_rec.Loan_ID, 'GSE Refinance Compliance', 'Major', 'Refinance_Documents',
                    'Required refinance-related documents must be present',
                    'Missing refinance documents for GSE eligibility', 'Y', SYSDATE
                );
                v_invalid_count := v_invalid_count + 1;
                CONTINUE;  -- Skip marking eligibility if validation fails
        END;

        -- Mark as eligible for GSE Targeted Refinance if all checks pass
        UPDATE Loan
        SET Eligibility_Status = 'GSE_REF_ELIG'
        WHERE Loan_ID = loan_rec.Loan_ID;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total invalid GSE eligibility entries found: ' || v_invalid_count);
END apply_property_valuation_logic;
/
