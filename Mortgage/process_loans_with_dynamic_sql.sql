CREATE OR REPLACE PROCEDURE process_loans_with_dynamic_sql (
    p_loan_term          IN NUMBER,                   -- Loan term filter (e.g., 360 for 30-year loans)
    p_loan_type          IN VARCHAR2 DEFAULT NULL,    -- Loan type filter (e.g., 'Fixed', 'ARM')
    p_min_interest_rate  IN NUMBER DEFAULT NULL,      -- Minimum interest rate filter
    p_max_interest_rate  IN NUMBER DEFAULT NULL,      -- Maximum interest rate filter
    p_status             OUT VARCHAR2                 -- Status message output
) AS
    v_cursor_id          NUMBER;                      -- Cursor ID for dynamic SQL
    v_sql_stmt           VARCHAR2(4000);              -- SQL statement to be constructed dynamically
    v_loan_id            Loan.Loan_ID%TYPE;           -- Variable to hold fetched Loan_ID
    v_interest_rate      Loan.Interest_Rate%TYPE;     -- Variable to hold fetched Interest_Rate
    v_credit_score       Loan.Borrower_Credit_Score%TYPE; -- Borrower's credit score
    v_row_count          NUMBER := 0;                 -- Number of loans processed

    -- Variables for business logic
    v_risk_score         NUMBER(5,2);                 -- Calculated risk score

    -- Variables for dynamic update
    v_update_stmt        VARCHAR2(4000);              -- Update statement for dynamic SQL
    v_update_cursor_id   NUMBER;                      -- Cursor ID for dynamic SQL update

    -- Variables to capture return values from DBMS_SQL.EXECUTE
    v_execute_result     INTEGER;
    v_update_result      INTEGER;

BEGIN
    -- Step 1: Construct the dynamic SQL statement based on input parameters
    v_sql_stmt := 'SELECT Loan_ID, Interest_Rate, Borrower_Credit_Score FROM Loan WHERE Loan_Term = :loan_term';

    IF p_loan_type IS NOT NULL THEN
        v_sql_stmt := v_sql_stmt || ' AND Loan_Type = :loan_type';
    END IF;

    IF p_min_interest_rate IS NOT NULL THEN
        v_sql_stmt := v_sql_stmt || ' AND Interest_Rate >= :min_interest_rate';
    END IF;

    IF p_max_interest_rate IS NOT NULL THEN
        v_sql_stmt := v_sql_stmt || ' AND Interest_Rate <= :max_interest_rate';
    END IF;

    -- Step 2: Open a dynamic SQL cursor
    v_cursor_id := DBMS_SQL.OPEN_CURSOR;

    -- Step 3: Prepare the dynamic SQL statement
    DBMS_SQL.PARSE(v_cursor_id, v_sql_stmt, DBMS_SQL.NATIVE);

    -- Step 4: Bind variables
    DBMS_SQL.BIND_VARIABLE(v_cursor_id, ':loan_term', p_loan_term);

    IF p_loan_type IS NOT NULL THEN
        DBMS_SQL.BIND_VARIABLE(v_cursor_id, ':loan_type', p_loan_type);
    END IF;

    IF p_min_interest_rate IS NOT NULL THEN
        DBMS_SQL.BIND_VARIABLE(v_cursor_id, ':min_interest_rate', p_min_interest_rate);
    END IF;

    IF p_max_interest_rate IS NOT NULL THEN
        DBMS_SQL.BIND_VARIABLE(v_cursor_id, ':max_interest_rate', p_max_interest_rate);
    END IF;

    -- Step 5: Define columns to retrieve from the dynamic SQL query
    DBMS_SQL.DEFINE_COLUMN(v_cursor_id, 1, v_loan_id, 12);          -- Loan_ID
    DBMS_SQL.DEFINE_COLUMN(v_cursor_id, 2, v_interest_rate);        -- Interest_Rate
    DBMS_SQL.DEFINE_COLUMN(v_cursor_id, 3, v_credit_score);         -- Borrower_Credit_Score

    -- Step 6: Execute the SQL statement and capture the return value
    v_execute_result := DBMS_SQL.EXECUTE(v_cursor_id);

    -- Fetch and process rows
    LOOP
        EXIT WHEN DBMS_SQL.FETCH_ROWS(v_cursor_id) = 0;

        -- Get values of defined columns
        DBMS_SQL.COLUMN_VALUE(v_cursor_id, 1, v_loan_id);
        DBMS_SQL.COLUMN_VALUE(v_cursor_id, 2, v_interest_rate);
        DBMS_SQL.COLUMN_VALUE(v_cursor_id, 3, v_credit_score);

        -- Perform business logic: calculate risk score
        IF v_credit_score > 0 THEN
            v_risk_score := (v_interest_rate * 100) / v_credit_score;
        ELSE
            v_risk_score := NULL;
        END IF;

        -- Update the Loan table with the calculated risk score using dynamic SQL
        v_update_stmt := 'UPDATE Loan SET Risk_Score = :risk_score WHERE Loan_ID = :loan_id';
        v_update_cursor_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(v_update_cursor_id, v_update_stmt, DBMS_SQL.NATIVE);
        DBMS_SQL.BIND_VARIABLE(v_update_cursor_id, ':risk_score', v_risk_score);
        DBMS_SQL.BIND_VARIABLE(v_update_cursor_id, ':loan_id', v_loan_id);
        v_update_result := DBMS_SQL.EXECUTE(v_update_cursor_id);  -- Capture the return value
        DBMS_SQL.CLOSE_CURSOR(v_update_cursor_id);

        -- Output each processed loan's details
        DBMS_OUTPUT.PUT_LINE('Processed Loan ID: ' || v_loan_id ||
                             ', Interest Rate: ' || v_interest_rate ||
                             ', Credit Score: ' || v_credit_score ||
                             ', Risk Score: ' || NVL(TO_CHAR(v_risk_score, '90.99'), 'N/A'));

        v_row_count := v_row_count + 1;
    END LOOP;

    -- Close the cursor
    DBMS_SQL.CLOSE_CURSOR(v_cursor_id);

    -- Commit the updates
    COMMIT;

    -- Return a status message indicating completion
    p_status := 'Processing completed. Total loans processed: ' || v_row_count;

EXCEPTION
    WHEN OTHERS THEN
        -- Close cursors if open
        IF DBMS_SQL.IS_OPEN(v_cursor_id) THEN
            DBMS_SQL.CLOSE_CURSOR(v_cursor_id);
        END IF;
        IF DBMS_SQL.IS_OPEN(v_update_cursor_id) THEN
            DBMS_SQL.CLOSE_CURSOR(v_update_cursor_id);
        END IF;
        -- Rollback in case of errors
        ROLLBACK;
        p_status := 'Error: ' || SQLERRM;
END process_loans_with_dynamic_sql;
/
