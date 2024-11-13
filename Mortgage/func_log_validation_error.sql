CREATE OR REPLACE FUNCTION log_validation_error (
    p_loan_id            IN VARCHAR2,
    p_error_type         IN VARCHAR2,
    p_error_severity     IN VARCHAR2,
    p_field_name         IN VARCHAR2,
    p_validation_rule    IN VARCHAR2,
    p_error_message      IN VARCHAR2,
    p_user_action        IN VARCHAR2
) RETURN BOOLEAN IS
BEGIN
    -- Insert validation error into Loan_Validation_Errors table
    INSERT INTO Loan_Validation_Errors (Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required)
    VALUES (p_loan_id, p_error_type, p_error_severity, p_field_name, p_validation_rule, p_error_message, p_user_action);

    -- Return TRUE to indicate success
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        -- Log any error that occurs
        DBMS_OUTPUT.PUT_LINE('Error logging validation: ' || SQLERRM);
        RETURN FALSE;
END log_validation_error;
/
