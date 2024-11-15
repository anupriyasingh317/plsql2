BEGIN
  fetch_loans_by_date_range(
    p_start_date => TO_DATE('01-JAN-2021', 'DD-MON-YYYY'),
    p_end_date => TO_DATE('31-DEC-2021', 'DD-MON-YYYY'),
    p_foreclosure_status => 'Active',
    p_foreclosure_start => TO_DATE('01-JUN-2021', 'DD-MON-YYYY')
  );
END;
/
