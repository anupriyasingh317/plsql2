/*
After running merge_loan_datasets, verify the Results:

Check the Loan table to ensure that the records have been updated with the Refinanced_Loan_ID.
Check the Loan_Validation_Errors table for any inconsistencies (e.g., missing refinanced loans).
Review the Data_Ingestion_Log table for the status of the merge process.
*/

DECLARE
    v_status VARCHAR2(4000);
BEGIN
    merge_loan_datasets(p_mapping_file => 'mapping_file.csv', p_status => v_status);
    DBMS_OUTPUT.PUT_LINE(v_status);
END;
/

