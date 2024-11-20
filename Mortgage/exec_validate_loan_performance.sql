DECLARE
  v_status VARCHAR2(40) := '';
BEGIN
  validate_loan_performance(v_status);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END;
/