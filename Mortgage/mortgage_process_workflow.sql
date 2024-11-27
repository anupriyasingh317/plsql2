CREATE OR REPLACE PROCEDURE mortgage_process_workflow AS
    v_status VARCHAR2(4000);  -- Variable to hold the status message

BEGIN
    -- Call process_loan_data to load and validate data
    process_loan_data(
        p_file_name => 'loan_data_file.csv',
        p_mapping_file => 'mapping_file.csv',
        p_status => v_status
    );
    DBMS_OUTPUT.PUT_LINE('process_loan_data completed: ' || v_status);

    -- Apply property valuation logic for compliance checks
    apply_property_valuation_logic;
    DBMS_OUTPUT.PUT_LINE('apply_property_valuation_logic completed.');

    -- Validate foreclosure costs in addition to property valuation methods
    validate_foreclosure_costs;
    DBMS_OUTPUT.PUT_LINE('validate_foreclosure_costs completed.');

    -- Validate property valuation method and foreclosure costs
    validate_property_valuation_method;
    DBMS_OUTPUT.PUT_LINE('validate_property_valuation_method completed.');

    -- Validate Loan Eligibility
    validate_loan_eligibility(p_status => v_status);
    DBMS_OUTPUT.PUT_LINE('validate_loan_eligibility completed.'|| v_status);
	
    -- Call process_loans_with_dynamic_sql with a sample loan term
    process_loans_with_dynamic_sql(p_loan_term => 360, p_status => v_status);
    DBMS_OUTPUT.PUT_LINE('fetch_loans_with_dynamic_sql completed: ' || v_status);

    -- Corrected call to fetch_loans_by_date_range with sample dates and foreclosure parameters
    fetch_loans_by_date_range(
        p_start_date => TO_DATE('01-JAN-2021', 'DD-MON-YYYY'),
        p_end_date => TO_DATE('31-DEC-2021', 'DD-MON-YYYY'),
        p_foreclosure_status => 'Active',                     -- Added parameter for foreclosure status
        p_foreclosure_start => TO_DATE('01-JUN-2021', 'DD-MON-YYYY')  -- Added parameter for foreclosure start date
    );
    DBMS_OUTPUT.PUT_LINE('fetch_loans_by_date_range completed.');

END mortgage_process_workflow;
/
