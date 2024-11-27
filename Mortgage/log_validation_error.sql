CREATE OR REPLACE PROCEDURE log_validation_error(
    p_loan_id              IN VARCHAR2,
    p_error_type           IN VARCHAR2,
    p_error_severity       IN VARCHAR2,
    p_field_name           IN VARCHAR2,
    p_validation_rule      IN VARCHAR2,
    p_error_message        IN VARCHAR2,
    p_user_action_required IN VARCHAR2
) IS
BEGIN
    INSERT INTO Loan_Validation_Errors (
        Loan_ID,
        Error_Type,
        Error_Severity,
        Field_Name,
        Validation_Rule,
        Error_Message,
        User_Action_Required,
        Error_Date
    ) VALUES (
        p_loan_id,
        p_error_type,
        p_error_severity,
        p_field_name,
        p_validation_rule,
        p_error_message,
        p_user_action_required,
        SYSDATE
    );
END log_validation_error;
/