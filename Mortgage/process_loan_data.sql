CREATE OR REPLACE PROCEDURE process_loan_data (
    p_file_name      IN VARCHAR2,        -- Name of the data file
    p_mapping_file   IN VARCHAR2,        -- Name of the mapping file
    p_status         OUT VARCHAR2        -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message VARCHAR2(4000);
    v_log_id        NUMBER;
    v_invalid_record_count NUMBER := 0;
    v_valid_record_count NUMBER := 0;

    -- Variables for staging data
    v_loan_id                 Loan.Loan_ID%TYPE;
    v_ref_pool_id             Loan.Reference_Pool_ID%TYPE;
    v_original_upb            Loan.Original_UPB%TYPE;
    v_current_upb             Loan.Current_UPB%TYPE;
    v_origination_date        Loan.Origination_Date%TYPE;
    v_first_payment_date      Loan.First_Payment_Date%TYPE;
    v_loan_term               Loan.Loan_Term%TYPE;
    v_interest_rate           Loan.Interest_Rate%TYPE;
    v_loan_purpose            Loan.Loan_Purpose%TYPE;
    v_property_type           Loan.Property_Type%TYPE;
    v_loan_type               Loan.Loan_Type%TYPE;
    v_ltv                     Loan.LTV%TYPE;
    v_cltv                    Loan.CLTV%TYPE;
    v_dti                     Loan.Debt_to_Income%TYPE;
    v_borrower_credit_score   Loan.Borrower_Credit_Score%TYPE;
    v_co_borrower_credit_score Loan.Borrower_Credit_Score%TYPE;
    v_first_time_homebuyer    Loan_Staging.First_Time_Homebuyer%TYPE;
    v_property_valuation_method VARCHAR2(1);

    -- Foreclosure-specific fields
    v_foreclosure_status      VARCHAR2(20);   -- Status of foreclosure
    v_foreclosure_start_date  DATE;           -- Start date of foreclosure process
    v_foreclosure_cost_amount NUMBER(12,2);   -- Initial foreclosure cost amount
    v_cost_type               VARCHAR2(50);   -- Type of foreclosure cost (e.g., Legal Fees)

    -- Variables for mapping data
    v_original_loan_id        Mapping_File.Original_Loan_ID%TYPE;  -- Missing variable
    v_refinanced_loan_id      Mapping_File.Refinanced_Loan_ID%TYPE;  -- Missing variable

    -- Cursor for loading data from Loan_Staging
    CURSOR staging_cur IS
        SELECT Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
               First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
               Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, Co_Borrower_Credit_Score, 
               First_Time_Homebuyer
        FROM Loan_Staging;

    -- Cursor for mapping file
    CURSOR mapping_cur IS
        SELECT Original_Loan_ID, Refinanced_Loan_ID
        FROM Mapping_File;

BEGIN
    -- Step 1: Log the start of the ingestion process
    INSERT INTO Data_Ingestion_Log (Log_ID, Process_Date, File_Name, Status, Created_By)
    VALUES (Data_Ingestion_Log_Seq.NEXTVAL, SYSDATE, p_file_name, 'Processing', USER)
    RETURNING Log_ID INTO v_log_id;

    -- Step 2: Load Data from Loan_Staging Cursor and Process Row by Row
    OPEN staging_cur;
    LOOP
        FETCH staging_cur INTO v_loan_id, v_ref_pool_id, v_original_upb, v_current_upb, v_origination_date, 
                          v_first_payment_date, v_loan_term, v_interest_rate, v_loan_purpose, v_property_type, 
                          v_loan_type, v_ltv, v_cltv, v_dti, v_borrower_credit_score, v_co_borrower_credit_score, 
                          v_first_time_homebuyer;
        EXIT WHEN staging_cur%NOTFOUND;

        IF v_ltv > 97 THEN
            -- Insert into Loan_Validation_Errors if LTV is invalid
            INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, 
                                                Validation_Rule, Error_Message, User_Action_Required, Error_Date)
            VALUES (v_loan_id, 'Data Validation', 'Major', 'LTV', 
                    'LTV must be <= 97%', 'Loan has LTV greater than 97%', 'Y', SYSDATE);
            v_invalid_record_count := v_invalid_record_count + 1;
        ELSE
            -- Determine foreclosure status and start date if applicable
            IF v_loan_type = 'Foreclosure' THEN
                v_foreclosure_status := 'Active';
                v_foreclosure_start_date := SYSDATE;  -- Set foreclosure start date to current date
            ELSE
                v_foreclosure_status := NULL;
                v_foreclosure_start_date := NULL;
            END IF;

            -- Insert valid loan data into Loan table
            INSERT INTO Loan (Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
                              First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
                              Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, Co_Borrower_Credit_Score, 
                              First_Time_Homebuyer, Property_Valuation_Method, Foreclosure_Status, Foreclosure_Start_Date, Created_By, Created_Date)
            VALUES (v_loan_id, v_ref_pool_id, v_original_upb, v_current_upb, v_origination_date, 
                    v_first_payment_date, v_loan_term, v_interest_rate, v_loan_purpose, v_property_type, 
                    v_loan_type, v_ltv, v_cltv, v_dti, v_borrower_credit_score, v_co_borrower_credit_score, 
                    v_first_time_homebuyer, v_property_valuation_method, v_foreclosure_status, v_foreclosure_start_date, USER, SYSDATE);
            v_valid_record_count := v_valid_record_count + 1;

            -- Insert initial foreclosure cost record if applicable
            IF v_foreclosure_status = 'Active' THEN
                v_cost_type := 'Initial Foreclosure Cost';
                v_foreclosure_cost_amount := 5000;  -- Example initial cost

                INSERT INTO Foreclosure_Costs (Loan_ID, Cost_Type, Cost_Amount, Cost_Date, Cost_Status, Created_By, Created_Date)
                VALUES (v_loan_id, v_cost_type, v_foreclosure_cost_amount, SYSDATE, 'Pending', USER, SYSDATE);
            END IF;
        END IF;
    END LOOP;
    CLOSE staging_cur;
    DBMS_OUTPUT.PUT_LINE('Loaded ' || v_valid_record_count || ' valid loans and ' || v_invalid_record_count || ' invalid loans.');

    -- Step 3: Update Loans Using Mapping File
    OPEN mapping_cur;
    LOOP
        FETCH mapping_cur INTO v_original_loan_id, v_refinanced_loan_id;
        EXIT WHEN mapping_cur%NOTFOUND;

        -- Update Refined Loan ID in Loan table
        UPDATE Loan
        SET Refinanced_Loan_ID = v_refinanced_loan_id
        WHERE Loan_ID = v_original_loan_id;
    END LOOP;
    CLOSE mapping_cur;

    -- Log merging completion
    DBMS_OUTPUT.PUT_LINE('Loan data merged successfully using mapping file.');

    -- Step 4: Log completion and commit
    UPDATE Data_Ingestion_Log
    SET Status = 'Success', Modified_By = USER, Modified_Date = SYSDATE
    WHERE Log_ID = v_log_id;

    COMMIT;
    p_status := 'Data ingestion completed: ' || v_valid_record_count || ' valid loans processed, ' || v_invalid_record_count || ' invalid loans found.';

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
