CREATE OR REPLACE PROCEDURE validate_loan_performance (
    p_status OUT VARCHAR2  -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_valid_record_count NUMBER := 0;
    v_invalid_record_count NUMBER := 0;
    v_log_id NUMBER;

BEGIN
    -- Step 1: Log the start of the validation process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, 'Loan_Performance_Validation', 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Validate Current Interest Rate (must be between 0% and 20%)
    BEGIN
        INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
        SELECT lp.Loan_ID,
               'Data Validation' AS Error_Type,
               'Major' AS Error_Severity,
               'Current_Interest_Rate' AS Field_Name,
               'Current Interest Rate must be between 0% and 20%' AS Validation_Rule,
               'Current interest rate outside valid range' AS Error_Message,
               'Y' AS User_Action_Required
        FROM Loan_Performance lp
        WHERE lp.Current_Interest_Rate < 0 OR lp.Current_Interest_Rate > 20;

        v_invalid_record_count := v_invalid_record_count + SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Invalid interest rate records found: ' || SQL%ROWCOUNT);
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during interest rate validation: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 3: Validate Delinquency Status (if payment is current, ensure Delinquency_Status is '00')
    BEGIN
        INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
        SELECT lp.Loan_ID,
               'Business Rule' AS Error_Type,
               'Major' AS Error_Severity,
               'Delinquency_Status' AS Field_Name,
               'If payment is current, Delinquency_Status must be "00"' AS Validation_Rule,
               'Loan is marked as current, but Delinquency Status is not "00"' AS Error_Message,
               'Y' AS User_Action_Required
        FROM Loan_Performance lp
        WHERE lp.Payment_Status = 'Current' AND lp.Delinquency_Status <> '00';

        v_invalid_record_count := v_invalid_record_count + SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Invalid delinquency status records found: ' || SQL%ROWCOUNT);
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during delinquency status validation: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 4: Validate that Current UPB decreases or remains constant over time
    BEGIN
        -- Nested query to check the change in UPB over time
        INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
        SELECT lp.Loan_ID,
               'Data Validation' AS Error_Type,
               'Critical' AS Error_Severity,
               'Current_UPB' AS Field_Name,
               'Current UPB must decrease or remain constant over time' AS Validation_Rule,
               'Current UPB has increased compared to the previous period' AS Error_Message,
               'Y' AS User_Action_Required
        FROM Loan_Performance lp
        WHERE lp.Current_UPB > (SELECT lp2.Current_UPB
                                FROM Loan_Performance lp2
                                WHERE lp2.Loan_ID = lp.Loan_ID
                                AND lp2.Reporting_Period = ADD_MONTHS(lp.Reporting_Period, -1));

        v_invalid_record_count := v_invalid_record_count + SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Invalid UPB records found: ' || SQL%ROWCOUNT);
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during UPB validation: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 5: Validate Loan Age (ensure Loan_Age is calculated correctly from the Origination_Date)
    BEGIN
        INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
        SELECT lp.Loan_ID,
               'Data Validation' AS Error_Type,
               'Major' AS Error_Severity,
               'Loan_Age' AS Field_Name,
               'Loan Age must match the time since the Origination Date' AS Validation_Rule,
               'Loan age does not match expected value based on origination date' AS Error_Message,
               'Y' AS User_Action_Required
        FROM Loan_Performance lp
        JOIN Loan l ON lp.Loan_ID = l.Loan_ID
        WHERE lp.Loan_Age <> MONTHS_BETWEEN(lp.Reporting_Period, l.Origination_Date);

        v_invalid_record_count := v_invalid_record_count + SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Invalid loan age records found: ' || SQL%ROWCOUNT);
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_status := 'Error during loan age validation: ' || v_error_message;
            UPDATE Data_Ingestion_Log
            SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
            WHERE Log_ID = v_log_id;
            ROLLBACK;
            RETURN;
    END;

    -- Step 6: Log Success and Commit
    UPDATE Data_Ingestion_Log
    SET Status = 'Success', Modified_By = USER, Modified_Date = SYSDATE
    WHERE Log_ID = v_log_id;

    COMMIT;
    p_status := 'Loan performance validation completed successfully: ' || v_invalid_record_count || ' invalid records found.';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        p_status := 'Unexpected error: ' || v_error_message;
        UPDATE Data_Ingestion_Log
        SET Status = 'Error', Error_Message = p_status, Modified_By = USER, Modified_Date = SYSDATE
        WHERE Log_ID = v_log_id;
        ROLLBACK;
END validate_loan_performance;
/
