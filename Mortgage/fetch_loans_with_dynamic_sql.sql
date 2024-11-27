CREATE OR REPLACE PROCEDURE fetch_loans_with_dynamic_sql (
    p_loan_term       IN NUMBER,         -- Loan term filter (e.g., 360 for 30-year loans)
    p_status          OUT VARCHAR2       -- Status message output
) AS
    v_cursor_id       NUMBER;            -- Cursor ID for dynamic SQL
    v_loan_id         Loan.Loan_ID%TYPE; -- Variable to hold fetched Loan_ID
    v_interest_rate   Loan.Interest_Rate%TYPE; -- Variable to hold fetched Interest_Rate
    v_row_count       NUMBER := 0;       -- Number of rows fetched

    TYPE LoanArray IS TABLE OF VARCHAR2(12) INDEX BY PLS_INTEGER;
    v_loan_id_array   LoanArray;         -- Array to hold Loan_ID results

BEGIN
    -- Step 1: Open a dynamic SQL cursor
    v_cursor_id := DBMS_SQL.OPEN_CURSOR;

    -- Step 2: Prepare the dynamic SQL statement with bind variables
    DBMS_SQL.PARSE(v_cursor_id, 
                   'SELECT Loan_ID, Interest_Rate FROM Loan WHERE Loan_Term = :loan_term', 
                   DBMS_SQL.NATIVE);

    -- Step 3: Bind the variable `loan_term`
    DBMS_SQL.BIND_VARIABLE(v_cursor_id, ':loan_term', p_loan_term);

    -- Step 4: Define columns to retrieve from the dynamic SQL query
    DBMS_SQL.DEFINE_COLUMN(v_cursor_id, 1, v_loan_id, 12);        -- Loan_ID with VARCHAR2 length 12
    DBMS_SQL.DEFINE_COLUMN(v_cursor_id, 2, v_interest_rate);      -- Interest_Rate (NUMBER)

    -- Step 5: Execute the SQL statement
    v_row_count := DBMS_SQL.EXECUTE(v_cursor_id);

    -- Fetch and output rows
    WHILE DBMS_SQL.FETCH_ROWS(v_cursor_id) > 0 LOOP
        -- Get values of defined columns
        DBMS_SQL.COLUMN_VALUE(v_cursor_id, 1, v_loan_id);
        DBMS_SQL.COLUMN_VALUE(v_cursor_id, 2, v_interest_rate);

        -- Store Loan_ID in array for demonstration
        v_loan_id_array(v_row_count) := v_loan_id;

        -- Output each fetched row's details
        DBMS_OUTPUT.PUT_LINE('Loan ID: ' || v_loan_id || 
                             ', Interest Rate: ' || v_interest_rate || 
                             ', Loan Term: ' || p_loan_term);
    END LOOP;

    -- Close the cursor
    DBMS_SQL.CLOSE_CURSOR(v_cursor_id);

    -- Return a status message indicating completion
    p_status := 'Fetch completed. Total rows fetched: ' || v_row_count;

EXCEPTION
    WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(v_cursor_id) THEN
            DBMS_SQL.CLOSE_CURSOR(v_cursor_id);
        END IF;
        p_status := 'Error: ' || SQLERRM;
END fetch_loans_with_dynamic_sql;
/
