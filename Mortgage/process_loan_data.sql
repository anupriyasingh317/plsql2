CREATE OR REPLACE PROCEDURE process_loan_data (
    p_file_name      IN VARCHAR2,        -- Name of the data file
    p_mapping_file   IN VARCHAR2,        -- Name of the mapping file
    p_status         OUT VARCHAR2        -- OUT Parameter: Success or Error message
) IS
    -- Local Variables
    v_error_message         VARCHAR2(4000);
    v_log_id                NUMBER;
    v_invalid_record_count  NUMBER := 0;
    v_valid_record_count    NUMBER := 0;

    -- Variables for staging data
    v_loan_id                   Loan.Loan_ID%TYPE;
    v_ref_pool_id               Loan.Reference_Pool_ID%TYPE;
    v_original_upb              Loan.Original_UPB%TYPE;
    v_current_upb               Loan.Current_UPB%TYPE;
    v_origination_date          Loan.Origination_Date%TYPE;
    v_first_payment_date        Loan.First_Payment_Date%TYPE;
    v_loan_term                 Loan.Loan_Term%TYPE;
    v_interest_rate             Loan.Interest_Rate%TYPE;
    v_loan_purpose              Loan.Loan_Purpose%TYPE;
    v_property_type             Loan.Property_Type%TYPE;
    v_loan_type                 Loan.Loan_Type%TYPE;
    v_ltv                       Loan.LTV%TYPE;  -- This will be recalculated
    v_cltv                      Loan.CLTV%TYPE;
    v_dti                       Loan.Debt_to_Income%TYPE;
    v_borrower_credit_score     Loan.Borrower_Credit_Score%TYPE;
    v_co_borrower_credit_score  Loan.Co_Borrower_Credit_Score%TYPE;
    v_first_time_homebuyer      Loan.First_Time_Homebuyer%TYPE;
    v_property_valuation_method Loan.Property_Valuation_Method%TYPE;

    -- New Variables for Property and LTV Calculations
    v_property_id               Property.Property_ID%TYPE;
    v_av                        NUMBER;
    v_adjusted_av               NUMBER;
    v_calculated_ltv            NUMBER;

    -- Foreclosure-specific fields
    v_foreclosure_status      Loan.Foreclosure_Status%TYPE;
    v_foreclosure_start_date  Loan.Foreclosure_Start_Date%TYPE;
    v_foreclosure_cost_amount NUMBER(12,2);
    v_cost_type               VARCHAR2(50);

	-- Variables for mapping data
	v_mapping_count      NUMBER;
    v_original_loan_id   Mapping_File.Original_Loan_ID%TYPE;
    v_refinanced_loan_id Mapping_File.Refinanced_Loan_ID%TYPE;

    -- Variables for additional validations
    v_error_flag           BOOLEAN := FALSE;
    v_error_message_detail VARCHAR2(4000);

    -- Additional Variables for Borrower Data
    v_monthly_income           Borrower.Monthly_Income%TYPE;
    v_monthly_debt             Borrower.Monthly_Debt%TYPE;
    v_calculated_dti           NUMBER(5,2);
    v_market_interest_rate     NUMBER(5,3);
    v_permissible_spread       NUMBER(5,3) := 3.0; -- Maximum allowable spread
    v_max_allowed_interest_rate NUMBER(5,3);

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

        v_error_flag := FALSE;
        v_error_message_detail := NULL;

        -- Fetch Property ID associated with the Loan
        BEGIN
            SELECT p.Property_ID
            INTO v_property_id
            FROM Property p
            WHERE p.Loan_ID = v_loan_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_error_flag := TRUE;
                v_error_message_detail := 'Property information not found.';
                log_validation_error(v_loan_id, 'Data Validation', 'Critical', 'Property Data', 
                                     'Property data must exist for each loan', 'Property data missing', 'Y');
        END;

        -- Proceed if no error in fetching property
        IF NOT v_error_flag THEN
            -- Calculate Appraised Value (AV)
            v_av := calculate_av(v_property_id);

            IF v_av IS NOT NULL THEN
                -- Calculate Adjusted Appraised Value
                v_adjusted_av := calculate_adjusted_av(v_av);

                -- Calculate LTV using the adjusted appraised value
                v_calculated_ltv := calculate_ltv(v_original_upb, v_adjusted_av);

                -- Validation: Check LTV
                IF v_calculated_ltv > 97 THEN
                    v_error_flag := TRUE;
                    v_error_message_detail := NVL(v_error_message_detail, '') || ' LTV must be <= 97%.';
                    log_validation_error(v_loan_id, 'Data Validation', 'Major', 'LTV', 
                                         'LTV must be <= 97%', 
                                         'Loan has LTV of ' || TO_CHAR(v_calculated_ltv, '90.99') || '%, which exceeds the maximum allowed.', 
                                         'Y');
                END IF;
            ELSE
                -- If Appraised Value is missing
                v_error_flag := TRUE;
                v_error_message_detail := NVL(v_error_message_detail, '') || ' Appraised Value is missing or invalid.';
                log_validation_error(v_loan_id, 'Data Validation', 'Critical', 'Appraised Value',
                                     'Appraised Value is required to calculate LTV',
                                     'Appraised Value is missing or invalid.', 'Y');
            END IF;
        END IF;

        -- Continue with other validations if no critical errors
        IF NOT v_error_flag THEN
            -- Fetch Borrower Data
            BEGIN
                SELECT b.Monthly_Income, b.Monthly_Debt
                INTO v_monthly_income, v_monthly_debt
                FROM Borrower b
                WHERE b.Loan_ID = v_loan_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_error_flag := TRUE;
                    v_error_message_detail := 'Borrower information not found.';
                    log_validation_error(v_loan_id, 'Data Validation', 'Critical', 'Borrower Data', 
                                         'Borrower data must exist for each loan', 'Borrower data missing', 'Y');
            END;

            IF NOT v_error_flag THEN
                -- Enhanced DTI Calculation and Validation
                IF v_monthly_income IS NOT NULL AND v_monthly_income > 0 THEN
                    v_calculated_dti := ROUND((v_monthly_debt / v_monthly_income) * 100, 2);
                    -- Validate that the calculated DTI matches the provided DTI within a 1% tolerance
                    IF ABS(v_calculated_dti - v_dti) > 1 THEN
                        v_error_flag := TRUE;
                        v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                  ' Calculated DTI does not match provided DTI.';
                        log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Debt_to_Income',
                                             'Calculated DTI must match provided DTI within 1%', 
                                             'Mismatch between calculated and provided DTI', 'Y');
                    END IF;
                    -- Credit Score Dependent DTI Thresholds
                    IF v_borrower_credit_score >= 720 THEN
                        IF v_calculated_dti > 45 THEN
                            v_error_flag := TRUE;
                            v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                      ' DTI exceeds 45% for credit score >= 720.';
                            log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Debt_to_Income',
                                                 'DTI must be <= 45% for credit score >= 720', 
                                                 'DTI exceeds allowed limit for high credit score', 'Y');
                        END IF;
                    ELSIF v_borrower_credit_score BETWEEN 680 AND 719 THEN
                        IF v_calculated_dti > 40 THEN
                            v_error_flag := TRUE;
                            v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                      ' DTI exceeds 40% for credit score between 680 and 719.';
                            log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Debt_to_Income',
                                                 'DTI must be <= 40% for credit score between 680 and 719', 
                                                 'DTI exceeds allowed limit for medium credit score', 'Y');
                        END IF;
                    ELSIF v_borrower_credit_score BETWEEN 640 AND 679 THEN
                        IF v_calculated_dti > 35 THEN
                            v_error_flag := TRUE;
                            v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                      ' DTI exceeds 35% for credit score between 640 and 679.';
                            log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Debt_to_Income',
                                                 'DTI must be <= 35% for credit score between 640 and 679', 
                                                 'DTI exceeds allowed limit for low credit score', 'Y');
                        END IF;
                    ELSE
                        IF v_calculated_dti > 30 THEN
                            v_error_flag := TRUE;
                            v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                      ' DTI exceeds 30% for credit score < 640.';
                            log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Debt_to_Income',
                                                 'DTI must be <= 30% for credit score < 640', 
                                                 'DTI exceeds allowed limit for very low credit score', 'Y');
                        END IF;
                    END IF;
                ELSE
                    v_error_flag := TRUE;
                    v_error_message_detail := NVL(v_error_message_detail, '') || 
                                              ' Monthly Income is missing or invalid.';
                    log_validation_error(v_loan_id, 'Data Validation', 'Critical', 'Monthly_Income',
                                         'Monthly Income must be provided and greater than 0', 
                                         'Missing or invalid Monthly Income', 'Y');
                END IF;

                -- Enhanced Interest Rate Validation
                BEGIN
                    SELECT Current_Rate
                    INTO v_market_interest_rate
                    FROM Market_Rate
                    WHERE Rate_Type = v_loan_type
                      AND Rate_Term = v_loan_term
                      AND Effective_Date = (SELECT MAX(Effective_Date) FROM Market_Rate
                                            WHERE Rate_Type = v_loan_type AND Rate_Term = v_loan_term);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_error_flag := TRUE;
                        v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                  ' Market interest rate data not found.';
                        log_validation_error(v_loan_id, 'Data Validation', 'Critical', 'Market_Rate',
                                             'Market rate data must be available for interest rate validation', 
                                             'Missing market rate data', 'Y');
                END;

                IF NOT v_error_flag THEN
                    v_max_allowed_interest_rate := v_market_interest_rate + v_permissible_spread;

                    IF v_interest_rate > v_max_allowed_interest_rate THEN
                        v_error_flag := TRUE;
                        v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                  ' Interest Rate exceeds maximum allowed rate.';
                        log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Interest_Rate',
                                             'Interest Rate must not exceed market rate plus permissible spread', 
                                             'Interest Rate exceeds maximum allowed limit', 'Y');
                    END IF;

                    -- Loan Type-Specific Interest Rate Checks
                    IF v_loan_type = 'Fixed' THEN
                        IF v_interest_rate < 2 OR v_interest_rate > 10 THEN
                            v_error_flag := TRUE;
                            v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                      ' Fixed loans must have Interest Rate between 2% and 10%.';
                            log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Interest_Rate',
                                                 'Fixed loans must have Interest Rate between 2% and 10%', 
                                                 'Invalid Interest Rate for Fixed Loan', 'Y');
                        END IF;
                    ELSIF v_loan_type = 'ARM' THEN
                        IF v_interest_rate < 1.5 OR v_interest_rate > 8 THEN
                            v_error_flag := TRUE;
                            v_error_message_detail := NVL(v_error_message_detail, '') || 
                                                      ' ARM loans must have Interest Rate between 1.5% and 8%.';
                            log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Interest_Rate',
                                                 'ARM loans must have Interest Rate between 1.5% and 8%', 
                                                 'Invalid Interest Rate for ARM Loan', 'Y');
                        END IF;
                    END IF;
                END IF;
            END IF;

            -- Validation: Check Loan Term
            IF v_loan_term < 10 OR v_loan_term > 30 THEN
                v_error_flag := TRUE;
                v_error_message_detail := NVL(v_error_message_detail, '') || 
                                          ' Loan Term must be between 10 and 30 years.';
                log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Loan_Term',
                                     'Loan Term must be between 10 and 30 years', 'Invalid Loan Term', 'Y');
            END IF;

            -- Validation: Check Borrower Credit Score
            IF v_borrower_credit_score < 300 OR v_borrower_credit_score > 850 THEN
                v_error_flag := TRUE;
                v_error_message_detail := NVL(v_error_message_detail, '') || 
                                          ' Borrower Credit Score must be between 300 and 850.';
                log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Borrower_Credit_Score',
                                     'Credit Score must be between 300 and 850', 'Invalid Borrower Credit Score', 'Y');
            END IF;

            -- Validation: Check Co-Borrower Credit Score
            IF v_co_borrower_credit_score IS NOT NULL THEN
                IF v_co_borrower_credit_score < 300 OR v_co_borrower_credit_score > 850 THEN
                    v_error_flag := TRUE;
                    v_error_message_detail := NVL(v_error_message_detail, '') || 
                                              ' Co-Borrower Credit Score must be between 300 and 850.';
                    log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Co_Borrower_Credit_Score',
                                         'Credit Score must be between 300 and 850', 'Invalid Co-Borrower Credit Score', 'Y');
                END IF;
            END IF;

            -- Validation: Check Dates
            IF v_first_payment_date < v_origination_date THEN
                v_error_flag := TRUE;
                v_error_message_detail := NVL(v_error_message_detail, '') || 
                                          ' First Payment Date cannot be earlier than Origination Date.';
                log_validation_error(v_loan_id, 'Data Validation', 'Major', 'First_Payment_Date',
                                     'First Payment Date cannot be earlier than Origination Date', 'Invalid Payment Date', 'Y');
            END IF;

            -- Validation: Check CLTV >= LTV
            IF v_cltv < v_calculated_ltv THEN
                v_error_flag := TRUE;
                v_error_message_detail := NVL(v_error_message_detail, '') || 
                                          ' CLTV must be greater than or equal to LTV.';
                log_validation_error(v_loan_id, 'Data Validation', 'Major', 'CLTV',
                                     'CLTV must be >= LTV', 'Invalid CLTV', 'Y');
            END IF;

            -- Validation: Cross-validation between First Time Homebuyer and Loan Purpose
            IF v_first_time_homebuyer = 'Y' AND v_loan_purpose <> 'Purchase' THEN
                v_error_flag := TRUE;
                v_error_message_detail := NVL(v_error_message_detail, '') || 
                                          ' First Time Homebuyer loans must have Loan Purpose as Purchase.';
                log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Loan_Purpose',
                                     'First Time Homebuyer loans must be Purchase', 'Mismatch in Loan Purpose', 'Y');
            END IF;

            -- Validation: If Loan Purpose is Refinance, check mapping file
            IF v_loan_purpose = 'Refinance' THEN
                SELECT COUNT(*)
                INTO v_mapping_count
                FROM Mapping_File
                WHERE Original_Loan_ID = v_loan_id;
                IF v_mapping_count = 0 THEN
                    v_error_flag := TRUE;
                    v_error_message_detail := NVL(v_error_message_detail, '') || 
                                              ' Refinance loans must have a mapping in Mapping_File.';
                    log_validation_error(v_loan_id, 'Data Validation', 'Major', 'Loan_ID',
                                         'Refinance loans must have mapping in Mapping_File', 'Missing mapping for Refinance Loan', 'Y');
                END IF;
            END IF;
        END IF;

        -- Check if any validation errors occurred
        IF v_error_flag THEN
            v_invalid_record_count := v_invalid_record_count + 1;
        ELSE
            -- Determine foreclosure status and start date if applicable
            IF v_loan_type = 'Foreclosure' THEN
                v_foreclosure_status     := 'Active';
                v_foreclosure_start_date := SYSDATE;
            ELSE
                v_foreclosure_status     := NULL;
                v_foreclosure_start_date := NULL;
            END IF;

            -- Insert valid loan data into Loan table
            INSERT INTO Loan (Loan_ID, Reference_Pool_ID, Original_UPB, Current_UPB, Origination_Date, 
                              First_Payment_Date, Loan_Term, Interest_Rate, Loan_Purpose, Property_Type, 
                              Loan_Type, LTV, CLTV, Debt_to_Income, Borrower_Credit_Score, 
                              Co_Borrower_Credit_Score, First_Time_Homebuyer, Property_Valuation_Method, 
                              Foreclosure_Status, Foreclosure_Start_Date, Created_By, Created_Date)
            VALUES (v_loan_id, v_ref_pool_id, v_original_upb, v_current_upb, v_origination_date, 
                    v_first_payment_date, v_loan_term, v_interest_rate, v_loan_purpose, v_property_type, 
                    v_loan_type, v_calculated_ltv, v_cltv, v_dti, v_borrower_credit_score, 
                    v_co_borrower_credit_score, v_first_time_homebuyer, v_property_valuation_method, 
                    v_foreclosure_status, v_foreclosure_start_date, USER, SYSDATE);
            v_valid_record_count := v_valid_record_count + 1;

            -- Insert initial foreclosure cost record if applicable
            IF v_foreclosure_status = 'Active' THEN
                v_cost_type               := 'Initial Foreclosure Cost';
                v_foreclosure_cost_amount := 5000;

                INSERT INTO Foreclosure_Costs (Loan_ID, Cost_Type, Cost_Amount, Cost_Date, 
                                               Cost_Status, Created_By, Created_Date)
                VALUES (v_loan_id, v_cost_type, v_foreclosure_cost_amount, SYSDATE, 
                        'Pending', USER, SYSDATE);
            END IF;
        END IF;
    END LOOP;
    CLOSE staging_cur;

    DBMS_OUTPUT.PUT_LINE('Loaded ' || v_valid_record_count || 
                         ' valid loans and ' || v_invalid_record_count || ' invalid loans.');

    -- Step 3: Update Loans Using Mapping File
    OPEN mapping_cur;
    LOOP
        FETCH mapping_cur INTO v_original_loan_id, v_refinanced_loan_id;
        EXIT WHEN mapping_cur%NOTFOUND;

        -- Update Refinanced Loan ID in Loan table
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
    p_status := 'Data ingestion completed: ' || v_valid_record_count || 
                ' valid loans processed, ' || v_invalid_record_count || ' invalid loans found.';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        p_status        := 'Unexpected error: ' || v_error_message;
        UPDATE Data_Ingestion_Log
        SET Status        = 'Error',
            Error_Message = p_status,
            Modified_By   = USER,
            Modified_Date = SYSDATE
        WHERE Log_ID = v_log_id;
        ROLLBACK;
END process_loan_data;
/
