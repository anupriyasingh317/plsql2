CREATE OR REPLACE PROCEDURE exclude_ineligible_loans (
    p_status OUT VARCHAR2  -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_ineligible_loan_count NUMBER := 0;
    v_log_id NUMBER;
    v_ineligible BOOLEAN := FALSE;

    -- Enhanced Cursor for loans with joins and conditions
    CURSOR loan_cur IS
        SELECT l.Loan_ID, 
               l.Loan_Type, 
               l.Balloon_Indicator, 
               l.Interest_Only_Indicator, 
               l.LTV, 
               l.Loan_Purpose, 
               l.Prepayment_Penalty_Indicator,
               COALESCE(lm.Modification_Flag, 'N') AS Modification_Flag,
               ls.Loan_Status,
               lm.Modification_Date,
               ls.Delinquency_Flag
        FROM Loan l
        LEFT JOIN Loan_Modification lm ON l.Loan_ID = lm.Loan_ID
        LEFT JOIN Loan_Status ls ON l.Loan_ID = ls.Loan_ID
        WHERE l.Loan_Type = 'Fixed'
        AND l.LTV <= 97
        AND (lm.Modification_Flag = 'N' OR lm.Modification_Flag IS NULL)
        AND ls.Loan_Status = 'Active'
        AND ls.Delinquency_Flag = 'N'
        AND l.Origination_Date > TO_DATE('01-JAN-2000', 'DD-MON-YYYY')
        ORDER BY l.Loan_ID;

    -- Cursor for properties
    CURSOR property_cur IS
        SELECT Property_ID, Loan_ID, Property_Type, Occupancy_Status, Property_Condition, Flood_Zone, Flood_Insurance
        FROM Property;

    -- Cursor for borrowers
    CURSOR borrower_cur IS
        SELECT Borrower_ID, Loan_ID, Borrower_Credit_Score, Debt_to_Income, Income_Documentation_Status, 
               Employment_Verification_Status
        FROM Borrower;

BEGIN
    -- Step 1: Log the start of the exclusion process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, 'Loan_Exclusion_Process', 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Loan Ineligibility Checks Using Cursor
    FOR loan_rec IN loan_cur LOOP
        -- Reset ineligible flag for each loan
        v_ineligible := FALSE;

        -- Loan Type check (ARM)
        IF loan_rec.Loan_Type = 'ARM' THEN
            v_ineligible := log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Loan_Type',
                                                 'Loan_Type must be Fixed-Rate', 'Loan is an ARM', 'Y');
        END IF;

        -- Balloon Mortgage check
        IF loan_rec.Balloon_Indicator = 'Y' THEN
            v_ineligible := log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Balloon_Indicator',
                                                 'Loan must not be a Balloon Mortgage', 'Loan is a Balloon Mortgage', 'Y');
        END IF;

        -- Interest-Only Loan check
        IF loan_rec.Interest_Only_Indicator = 'Y' THEN
            v_ineligible := log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Interest_Only_Indicator',
                                                 'Loan must not be Interest-Only', 'Loan is an Interest-Only Loan', 'Y');
        END IF;

        -- LTV check (greater than 97%)
        IF loan_rec.LTV > 97 THEN
            v_ineligible := log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Critical', 'LTV',
                                                 'LTV must be <= 97%', 'Loan has an LTV greater than 97%', 'Y');
        END IF;

        -- Government-insured Loan check
        IF loan_rec.Loan_Purpose = 'Government-Insured' THEN
            v_ineligible := log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Major', 'Loan_Purpose',
                                                 'Loan must not be government-insured', 'Loan is government-insured', 'Y');
        END IF;

        -- Prepayment Penalty check
        IF loan_rec.Prepayment_Penalty_Indicator = 'Y' THEN
            v_ineligible := log_validation_error(loan_rec.Loan_ID, 'Loan Ineligibility', 'Minor', 'Prepayment_Penalty_Indicator',
                                                 'Loan must not have a prepayment penalty', 'Loan has a prepayment penalty', 'Y');
        END IF;

        -- Increment the ineligible loan count if the loan was marked ineligible
        IF v_ineligible THEN
            v_ineligible_loan_count := v_ineligible_loan_count + 1;
        END IF;

    END LOOP;

    -- Additional property and borrower checks would follow a similar logic using the property_cur and borrower_cur cursors

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
END exclude_ineligible_loans;
/
