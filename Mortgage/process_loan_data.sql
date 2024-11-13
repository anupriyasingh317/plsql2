CREATE OR REPLACE PROCEDURE process_loan_data (
    p_file_name      IN VARCHAR2,        -- Name of the data file
    p_mapping_file   IN VARCHAR2,        -- Name of the mapping file
    p_status         OUT VARCHAR2        -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_ref_pool_id   VARCHAR2(10);
    v_loan_count    NUMBER;
    v_valid_record_count NUMBER := 0;
    v_invalid_record_count NUMBER := 0;
    v_log_id        NUMBER;

BEGIN
    -- Step 1: Log the start of the ingestion process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, p_file_name, 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Load Data from Primary and Secondary Datasets
    BEGIN
        -- Load primary dataset (loan data) into the staging table
        INSERT INTO Loan_Staging (Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
                                  First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
                                  Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, Co_Borrower_Credit_Score, 
                                  First_Time_Homebuyer)
        SELECT Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
               First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
               Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, Co_Borrower_Credit_Score, 
               First_Time_Homebuyer
        FROM external_loan_source_file;  -- External table or source file (assumed to be defined)

        -- Log the success of the primary dataset load
        v_loan_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Loaded ' || v_loan_count || ' loans from primary dataset.');

    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during primary dataset load: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 3: Merge Data Using the Mapping File
    BEGIN
        -- Load mapping file and merge original loans with refinanced loans
        MERGE INTO Loan l
        USING Mapping_File m
        ON (l.Loan_ID = m.Original_Loan_ID)
        WHEN MATCHED THEN
            UPDATE SET l.Loan_ID = m.Refinanced_Loan_ID;

        DBMS_OUTPUT.PUT_LINE('Loans merged successfully using the mapping file.');
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

    -- Step 4: Validate Data and Filter Invalid Records
    BEGIN
		-- Validate loans with invalid LTV (> 97%) and move to error table
		INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, 
											Validation_Rule, Error_Message, User_Action_Required)
		SELECT Loan_ID, 
			   'Data Validation',              -- Error_Type
			   'Major',                        -- Error_Severity
			   'LTV',                          -- Field_Name
			   'LTV must be ≤ 97%',            -- Validation_Rule
			   'Loan has LTV greater than 97%',-- Error_Message
			   'Y'                             -- User_Action_Required
		FROM Loan_Staging
		WHERE LTV > 97;

        -- Log number of invalid records
        v_invalid_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Invalid records found: ' || v_invalid_record_count || ' loans with invalid LTV.');

        -- Process valid loans
        INSERT INTO Loan (Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
                          First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
                          Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, Co_Borrower_Credit_Score, 
                          First_Time_Homebuyer, Created_By, Created_Date)
        SELECT Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
               First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
               Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, Co_Borrower_Credit_Score, 
               First_Time_Homebuyer, USER, SYSDATE
        FROM Loan_Staging
        WHERE LTV <= 97;

        -- Log number of valid records
        v_valid_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Valid records processed: ' || v_valid_record_count);
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during validation process: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 5: Complete the Log and Commit
    UPDATE Data_Ingestion_Log
    SET Status = 'Success', Modified_By = USER, Modified_Date = SYSDATE
    WHERE Log_ID = v_log_id;

    COMMIT;
    p_status := 'Data ingestion completed successfully: ' || v_valid_record_count || ' valid loans processed, ' || v_invalid_record_count || ' invalid loans found.';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        p_status := 'Unexpected error: ' || v_error_message;
        UPDATE Data_Ingestion_Log
        SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
        WHERE Log_ID = v_log_id;
        ROLLBACK;
END process_loan_data;
/
