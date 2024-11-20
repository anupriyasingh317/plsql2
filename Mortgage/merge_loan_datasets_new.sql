CREATE OR REPLACE PROCEDURE merge_loan_datasets (
    p_mapping_file   IN VARCHAR2,   -- Name of the mapping file (for logging purposes)
    p_status         OUT VARCHAR2   -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_log_id        NUMBER;
    v_invalid_record_count NUMBER := 0;
    v_updated_record_count NUMBER := 0;
    v_inserted_record_count NUMBER := 0;

    -- Cursor to fetch data from Mapping_File and Loan_Performance for refinanced loans
    CURSOR mapping_cur IS
        SELECT m.Refinanced_Loan_ID, lp.Current_UPB, lp.Current_Interest_Rate
        FROM Mapping_File m
        JOIN Loan_Performance lp ON m.Refinanced_Loan_ID = lp.Loan_ID;

    -- Variables to store fetched values from cursor
    v_refinanced_loan_id Loan.Loan_ID%TYPE;
    v_current_upb Loan.Current_UPB%TYPE;
    v_current_interest_rate Loan.Interest_Rate%TYPE;

BEGIN
    -- Step 1: Log the start of the merge process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, p_mapping_file, 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Open the cursor and process each record in Mapping_File
    OPEN mapping_cur;
    LOOP
        FETCH mapping_cur INTO v_refinanced_loan_id, v_current_upb, v_current_interest_rate;
        EXIT WHEN mapping_cur%NOTFOUND;

        -- Step 2a: Check if the refinanced loan exists in the Loan table
		DECLARE
			v_loan_exists BOOLEAN;
		BEGIN
			SELECT EXISTS (
				SELECT 1
				FROM Loan
				WHERE Loan_ID = v_refinanced_loan_id
				)
			INTO v_loan_exists
			FROM DUAL;
		END;
		

        -- Step 2b: Update or Insert the loan based on existence
        IF v_loan_exists THEN
            -- If loan exists, update the record
            UPDATE Loan
            SET Current_UPB = v_current_upb,
                Interest_Rate = v_current_interest_rate,
                Modified_By = USER,
                Modified_Date = SYSDATE
            WHERE Loan_ID = v_refinanced_loan_id;

            -- Increment the update counter
            v_updated_record_count := v_updated_record_count + 1;

        ELSE
            -- If loan does not exist, insert a new record
            INSERT INTO Loan (Loan_ID, Current_UPB, Interest_Rate, Created_By, Created_Date)
            VALUES (v_refinanced_loan_id, v_current_upb, v_current_interest_rate, USER, SYSDATE);

            -- Increment the insert counter
            v_inserted_record_count := v_inserted_record_count + 1;
        END IF;
    END LOOP;

    -- Close the cursor
    CLOSE mapping_cur;

    -- Log the number of updated and inserted records
    DBMS_OUTPUT.PUT_LINE('Loans updated successfully: ' || v_updated_record_count || ' records updated.');
    DBMS_OUTPUT.PUT_LINE('New refinanced loans inserted: ' || v_inserted_record_count || ' records added.');

    -- Step 3: Identify Inconsistencies (e.g., Missing Refinanced Loans)
    BEGIN
        -- Cursor to fetch records from Mapping_File where the refinanced loan is missing in Loan table
        FOR inconsistency_rec IN (SELECT m.Refinanced_Loan_ID
                                  FROM Mapping_File m
                                  WHERE NOT EXISTS (SELECT 1
                                                    FROM Loan l
                                                    WHERE l.Loan_ID = m.Refinanced_Loan_ID))
        LOOP
            -- Insert record into Loan_Validation_Errors for missing refinanced loans
            INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
            VALUES (inconsistency_rec.Refinanced_Loan_ID,
                    'Data Validation',
                    'Critical',
                    'Refinanced_Loan_ID',
                    'Loan must exist in Loan table after refinancing',
                    'Refinanced loan not found in Loan table',
                    'Y');

            -- Increment the invalid record counter
            v_invalid_record_count := v_invalid_record_count + 1;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('Inconsistent loan records found: ' || v_invalid_record_count || ' refinanced loans not found in Loan table.');

    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during inconsistency check: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 4: Complete the Log and Commit
    UPDATE Data_Ingestion_Log
    SET Status = 'Success', Modified_By = USER, Modified_Date = SYSDATE
    WHERE Log_ID = v_log_id;

    COMMIT;
    p_status := 'Loan datasets processed successfully: ' || v_updated_record_count || ' records updated, ' || v_inserted_record_count || ' records inserted, ' || v_invalid_record_count || ' inconsistencies found.';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        p_status := 'Unexpected error: ' || v_error_message;
        UPDATE Data_Ingestion_Log
        SET Status = 'Error', Error_Message = v_error_message, Modified_By = USER, Modified_Date = SYSDATE
        WHERE Log_ID = v_log_id;
        ROLLBACK;
END merge_loan_datasets;
/
