DECLARE
    v_status VARCHAR2(4000);
BEGIN
    process_loan_data(p_file_name => 'loan_data_file.csv', p_mapping_file => 'mapping_file.csv', p_status => v_status);
    DBMS_OUTPUT.PUT_LINE(v_status);
END;
/