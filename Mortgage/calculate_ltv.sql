CREATE OR REPLACE FUNCTION calculate_ltv(p_loan_amount NUMBER, p_adjusted_av NUMBER) RETURN NUMBER IS
    v_ltv NUMBER;
BEGIN
    v_ltv := (p_loan_amount / p_adjusted_av) * 100;
    RETURN v_ltv;
END calculate_ltv;
/