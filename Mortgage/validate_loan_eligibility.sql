CREATE OR REPLACE PROCEDURE validate_loan_eligibility (
    p_status OUT VARCHAR2  -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_ineligible_loan_count NUMBER := 0;
    v_log_id NUMBER;
    v_ltv NUMBER;             -- Variable to store the calculated LTV
    v_adjusted_av NUMBER;     -- Adjusted Appraised Value

    -- Cursor declaration must come before function/procedure declarations
    -- Enhanced Cursor for loans with joins and conditions
    CURSOR loan_cur IS
        SELECT l.Loan_ID, 
               l.Original_UPB, 
               p.Property_Value,
               l.Loan_Type, 
               l.Balloon_Indicator, 
               l.Interest_Only_Indicator, 
               l.LTV, 
               l.Loan_Purpose, 
               l.Prepayment_Penalty_Indicator,
               lm.Modification_Flag,
               ls.Loan_Status,
               lm.Modification_Date,
               ls.Delinquency_Flag
        FROM Loan l
        LEFT JOIN Loan_Modification lm ON l.Loan_ID = lm.Loan_ID  -- Join with Loan_Modification
        LEFT JOIN Loan_Status ls ON l.Loan_ID = ls.Loan_ID        -- Join with Loan_Status
        LEFT JOIN Property p ON l.Loan_ID = p.Loan_ID             -- Join with Property to get property value
        WHERE l.Loan_Type = 'Fixed'                               -- Only process fixed-rate loans
          AND (lm.Modification_Flag = 'N' OR lm.Modification_Flag IS NULL) -- Exclude modified loans
          AND ls.Loan_Status = 'Active'                           -- Only active loans
          AND ls.Delinquency_Flag = 'N'                           -- Exclude delinquent loans
          AND l.Origination_Date > TO_DATE('01-JAN-2000', 'DD-MON-YYYY')  -- Loans originated after 2000
        ORDER BY l.Loan_ID;

    -- Function to calculate Appraised Value (AV)
    FUNCTION calculate_av(p_loan_id IN VARCHAR2) RETURN NUMBER IS
        v_av NUMBER;
    BEGIN
        -- Retrieve Appraised Value from Property table
        SELECT p.Property_Value INTO v_av
        FROM Property p
        WHERE p.Loan_ID = p_loan_id;

        RETURN v_av;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;  -- No Appraised Value found for the loan
    END calculate_av;

    -- Function to get Market Conditions Adjustment (MCA)
    FUNCTION get_mca RETURN NUMBER IS
        v_mca NUMBER;
    BEGIN
        -- Retrieve MCA from a configuration table or use a constant
        v_mca := 0.95;  -- Example MCA value
        RETURN v_mca;
    END get_mca;

    -- Function to calculate LTV
    FUNCTION calculate_ltv(p_loan_amount NUMBER, p_adjusted_av NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN (p_loan_amount / p_adjusted_av) * 100;
    END calculate_ltv;

    -- Procedure to log validation errors
    PROCEDURE log_validation_error(
        p_loan_id              IN VARCHAR2,
        p_error_type           IN VARCHAR2,
        p_error_severity       IN VARCHAR2,
        p_field_name           IN VARCHAR2,
        p_validation_rule      IN VARCHAR2,
        p_error_message        IN VARCHAR2,
        p_user_action_required IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO Loan_Validation_Errors (
            Loan_ID,
            Error_Type,
            Error_Severity,
            Field_Name,
            Validation_Rule,
            Error_Message,
            User_Action_Required,
            Error_Date
        ) VALUES (
            p_loan_id,
            p_error_type,
            p_error_severity,
            p_field_name,
            p_validation_rule,
            p_error_message,
            p_user_action_required,
            SYSDATE
        );
    END log_validation_error;

BEGIN
    -- Step 1: Log the start of the exclusion process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, 'Loan_Exclusion_Process', 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Loan Ineligibility Checks Using Cursor
    FOR loan_rec IN loan_cur LOOP
        -- Initialize a flag to track ineligibility for each loan
        DECLARE
            v_ineligible BOOLEAN := FALSE;
            v_av NUMBER;
            v_mca NUMBER;
        BEGIN
            -- Step 2a: Calculate Appraised Value (AV)
            v_av := calculate_av(loan_rec.Loan_ID);

            IF v_av IS NOT NULL THEN
                -- Step 2b: Get Market Conditions Adjustment (MCA)
                v_mca := get_mca();

                -- Step 2c: Calculate Adjusted Appraised Value
                v_adjusted_av := v_av * v_mca;

                -- Step 2d: Calculate LTV using the adjusted appraised value
                v_ltv := calculate_ltv(loan_rec.Original_UPB, v_adjusted_av);

                -- LTV check (greater than 97%)
                IF v_ltv > 97 THEN
                    log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Critical', 'LTV',
                                         'LTV must be <= 97%',
                                         'Loan has an LTV of ' || TO_CHAR(v_ltv, '90.99') || '%, which exceeds the maximum allowed.',
                                         'Y');
                    v_ineligible := TRUE;
                END IF;
            ELSE
                -- If Appraised Value is missing
                log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Critical', 'Appraised Value',
                                     'Appraised Value is required to calculate LTV',
                                     'Appraised Value is missing or invalid.',
                                     'Y');
                v_ineligible := TRUE;
            END IF;

            -- Additional Ineligibility Checks

            -- Loan Type check (ARM)
            IF loan_rec.Loan_Type = 'ARM' THEN
                log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Loan_Type',
                                     'Loan_Type must be Fixed-Rate', 'Loan is an ARM', 'Y');
                v_ineligible := TRUE;
            END IF;

            -- Balloon Mortgage check
            IF loan_rec.Balloon_Indicator = 'Y' THEN
                log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Balloon_Indicator',
                                     'Loan must not be a Balloon Mortgage', 'Loan is a Balloon Mortgage', 'Y');
                v_ineligible := TRUE;
            END IF;

            -- Interest-Only Loan check
            IF loan_rec.Interest_Only_Indicator = 'Y' THEN
                log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Interest_Only_Indicator',
                                     'Loan must not be Interest-Only', 'Loan is an Interest-Only Loan', 'Y');
                v_ineligible := TRUE;
            END IF;

            -- Government-insured Loan check
            IF loan_rec.Loan_Purpose = 'Government-Insured' THEN
                log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Loan_Purpose',
                                     'Loan must not be government-insured', 'Loan is government-insured', 'Y');
                v_ineligible := TRUE;
            END IF;

            -- Prepayment Penalty check
            IF loan_rec.Prepayment_Penalty_Indicator = 'Y' THEN
                log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Minor', 'Prepayment_Penalty_Indicator',
                                     'Loan must not have a prepayment penalty', 'Loan has a prepayment penalty', 'Y');
                v_ineligible := TRUE;
            END IF;

            -- Increment the ineligible loan count if the loan was marked ineligible
            IF v_ineligible THEN
                v_ineligible_loan_count := v_ineligible_loan_count + 1;
            END IF;

        END;
    END LOOP;

    -- Step 5: Log Success and Commit
    UPDATE Data_Ingestion_Log
    SET Status = 'Success', Modified_By = USER, Modified_Date = SYSDATE
    WHERE Log_ID = v_log_id;

    COMMIT;
    p_status := 'Ineligibility checks completed: ' || v_ineligible_loan_count || ' ineligible loans found.';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        p_status := 'Unexpected error: ' || v_error_message;
        UPDATE Data_Ingestion_Log
        SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
        WHERE Log_ID = v_log_id;
        ROLLBACK;
END validate_loan_eligibility;
/
