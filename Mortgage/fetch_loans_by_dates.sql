CREATE OR REPLACE PROCEDURE fetch_loans_by_date_range (
    p_start_date           IN DATE,         -- Start date for the date range
    p_end_date             IN DATE,         -- End date for the date range
    p_foreclosure_status   IN VARCHAR2 DEFAULT NULL,  -- Optional foreclosure status filter
    p_foreclosure_start    IN DATE DEFAULT NULL       -- Optional foreclosure start date filter
) IS
  -- Define a cursor to select loan details within the specified date range
  CURSOR loan_cur IS
    SELECT Loan_ID, Original_UPB, LTV, Origination_Date, Foreclosure_Status, Foreclosure_Start_Date
    FROM Loan
    WHERE Origination_Date BETWEEN p_start_date AND p_end_date
      AND (p_foreclosure_status IS NULL OR Foreclosure_Status = p_foreclosure_status)  -- Foreclosure status filter
      AND (p_foreclosure_start IS NULL OR Foreclosure_Start_Date >= p_foreclosure_start) -- Foreclosure start date filter
    ORDER BY Loan_ID;

  -- Variables to store fetched values
  v_loan_id               Loan.Loan_ID%TYPE;
  v_original_upb          Loan.Original_UPB%TYPE;
  v_ltv                   Loan.LTV%TYPE;
  v_origination_date      Loan.Origination_Date%TYPE;
  v_foreclosure_status    Loan.Foreclosure_Status%TYPE;
  v_foreclosure_start_date Loan.Foreclosure_Start_Date%TYPE;

BEGIN
  -- Open the cursor
  OPEN loan_cur;

  -- Loop through each row fetched by the cursor
  LOOP
    FETCH loan_cur INTO v_loan_id, v_original_upb, v_ltv, v_origination_date, v_foreclosure_status, v_foreclosure_start_date;
    -- Exit when there are no more rows
    EXIT WHEN loan_cur%NOTFOUND;

    -- Output the loan details
    DBMS_OUTPUT.PUT_LINE(loan_cur%ROWCOUNT || '. Loan ID: ' || v_loan_id || 
                         ', Original UPB: ' || v_original_upb || 
                         ', LTV: ' || v_ltv || '%' ||
                         ', Origination Date: ' || TO_CHAR(v_origination_date, 'DD-MON-YYYY') ||
                         ', Foreclosure Status: ' || NVL(v_foreclosure_status, 'N/A') ||
                         ', Foreclosure Start Date: ' || NVL(TO_CHAR(v_foreclosure_start_date, 'DD-MON-YYYY'), 'N/A'));

    -- Add a special message when the 5th row is fetched
    IF loan_cur%ROWCOUNT = 5 THEN
       DBMS_OUTPUT.PUT_LINE('--- Fetched 5th row ---');
    END IF;
  END LOOP;

  -- Close the cursor
  CLOSE loan_cur;
END fetch_loans_by_date_range;
/
