CREATE OR REPLACE FUNCTION log_validation_error (
    p_loan_id            IN VARCHAR2,  -- Loan ID for which the error occurred
    p_error_type         IN VARCHAR2,  -- Type of error (e.g., Loan Ineligibility, Property Ineligibility)
    p_error_severity     IN VARCHAR2,  -- Severity of the error (e.g., Critical, Major, Minor)
    p_field_name         IN VARCHAR2,  -- Name of the field where the error occurred
    p_validation_rule    IN VARCHAR2,  -- The validation rule that was violated
    p_error_message      IN VARCHAR2,  -- Detailed error message
    p_user_action        IN VARCHAR2   -- Y/N indicating if user action is required
) RETURN BOOLEAN IS
BEGIN
    -- Insert validation error into Loan_Validation_Errors table
    INSERT INTO Loan_Validation_Errors (
        Loan_ID, Error_Type, Error_Severity, Field_Name, Validation_Rule, Error_Message, User_Action_Required, Error_Date
    ) VALUES (
        p_loan_id, p_error_type, p_error_severity, p_field_name, p_validation_rule, p_error_message, p_user_action, SYSDATE
    );

    -- Return TRUE to indicate success
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any unexpected errors and return FALSE if logging fails
        DBMS_OUTPUT.PUT_LINE('Error logging validation: ' || SQLERRM);
        RETURN FALSE;
END log_validation_error;
/
