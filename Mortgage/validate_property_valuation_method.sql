CREATE OR REPLACE PROCEDURE validate_property_valuation_method AS
    v_invalid_count NUMBER := 0;
    v_dummy NUMBER;  -- Variable for SELECT INTO checks
BEGIN
    -- Step 1: Validate Property Valuation Method
    FOR loan_rec IN (
        SELECT Loan.Loan_ID, Loan.Property_Valuation_Method, pv.Valuation_Code
        FROM Loan
        LEFT JOIN Property_Valuation_Method_Lookup pv
        ON Loan.Property_Valuation_Method = pv.Valuation_Code
        WHERE Loan.Property_Valuation_Method IS NULL 
           OR pv.Valuation_Code IS NULL  -- Selects only loans with invalid property valuation methods
    ) LOOP
        -- Log invalid property valuation methods
        INSERT INTO Loan_Validation_Errors (
            Loan_ID, Error_Type, Error_Severity, Field_Name, 
            Validation_Rule, Error_Message, User_Action_Required, Error_Date
        ) VALUES (
            loan_rec.Loan_ID, 'Data Validation', 'Critical', 'Property_Valuation_Method', 
            'Must be A, C, P, R, W, or O', 
            'Invalid property valuation method', 'Y', SYSDATE
        );
        v_invalid_count := v_invalid_count + 1;
    END LOOP;

    -- Step 2: Additional Check for Foreclosure Costs if in Foreclosure Status
    FOR loan_rec IN (
        SELECT Loan.Loan_ID, Loan.Foreclosure_Status
        FROM Loan
        WHERE Loan.Foreclosure_Status = 'Active'  -- Only loans in active foreclosure
    ) LOOP
        -- Check for the presence of required foreclosure costs in Foreclosure_Costs
        BEGIN
            -- Ensure at least one appraisal-related foreclosure cost exists for compliance
            SELECT 1 INTO v_dummy
            FROM Foreclosure_Costs
            WHERE Loan_ID = loan_rec.Loan_ID
              AND Cost_Type IN ('Appraisal Fee', 'Legal Fees', 'Property Maintenance')
              AND Cost_Status = 'Pending';

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Log an error if required foreclosure costs are missing or incomplete
                INSERT INTO Loan_Validation_Errors (
                    Loan_ID, Error_Type, Error_Severity, Field_Name, 
                    Validation_Rule, Error_Message, User_Action_Required, Error_Date
                ) VALUES (
                    loan_rec.Loan_ID, 'Foreclosure Compliance', 'Critical', 'Foreclosure Costs',
                    'Loans in foreclosure require appraisal, legal, and maintenance costs',
                    'Missing required foreclosure costs for compliance', 'Y', SYSDATE
                );
                v_invalid_count := v_invalid_count + 1;
        END;
    END LOOP;

    -- Output total invalid records for review
    DBMS_OUTPUT.PUT_LINE('Total invalid Property Valuation Method and Foreclosure Cost entries found: ' || v_invalid_count);
END validate_property_valuation_method;
/
