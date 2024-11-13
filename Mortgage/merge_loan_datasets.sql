CREATE OR REPLACE PROCEDURE merge_loan_datasets (
    p_mapping_file   IN VARCHAR2,   -- Name of the mapping file (for logging purposes)
    p_status         OUT VARCHAR2   -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_log_id        NUMBER;
    v_invalid_record_count NUMBER := 0;
    v_merged_record_count NUMBER := 0;

BEGIN
    -- Step 1: Log the start of the merge process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, p_mapping_file, 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Merge Original Loans with Refinanced Loans using the Mapping File
    BEGIN
        -- Merge refinanced loans from Mapping_File with original loans in the Loan table
        MERGE INTO Loan l
        USING Mapping_File m
        ON (l.Loan_ID = m.Original_Loan_ID)
        WHEN MATCHED THEN
            UPDATE SET l.Loan_ID = m.Refinanced_Loan_ID,  -- Update Loan_ID to the refinanced loan
                        l.Current_UPB = (SELECT lp.Current_UPB  -- Update Current UPB from performance data
                                         FROM Loan_Performance lp
                                         WHERE lp.Loan_ID = m.Refinanced_Loan_ID
                                         AND ROWNUM = 1),  -- Fetch the latest performance record
                        l.Interest_Rate = (SELECT lp.Current_Interest_Rate  -- Update interest rate
                                           FROM Loan_Performance lp
                                           WHERE lp.Loan_ID = m.Refinanced_Loan_ID
                                           AND ROWNUM = 1),
                        l.Modified_By = USER,
                        l.Modified_Date = SYSDATE;

        -- Log the number of merged records
        v_merged_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Loans merged successfully: ' || v_merged_record_count || ' records updated.');

    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during merging process: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 3: Identify Inconsistencies (e.g., Missing Refinanced Loans)
    BEGIN
        -- Insert records into Loan_Validation_Errors if any refinanced loans are missing in the Loan table
        INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
        SELECT m.Refinanced_Loan_ID,
               'Data Validation' AS Error_Type,
               'Critical' AS Error_Severity,
               'Refinanced_Loan_ID' AS Field_Name,
               'Loan must exist in Loan table after refinancing' AS Validation_Rule,
               'Refinanced loan not found in Loan table' AS Error_Message,
               'Y' AS User_Action_Required
        FROM Mapping_File m
        WHERE NOT EXISTS (
            SELECT 1
            FROM Loan l
            WHERE l.Loan_ID = m.Refinanced_Loan_ID
        );

        -- Log invalid records
        v_invalid_record_count := SQL%ROWCOUNT;
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
    p_status := 'Loan datasets merged successfully: ' || v_merged_record_count || ' records updated, ' || v_invalid_record_count || ' inconsistencies found.';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        p_status := 'Unexpected error: ' || v_error_message;
        UPDATE Data_Ingestion_Log
        SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
        WHERE Log_ID = v_log_id;
        ROLLBACK;
END merge_loan_datasets;
/
