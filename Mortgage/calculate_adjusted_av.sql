CREATE OR REPLACE FUNCTION calculate_adjusted_av(p_av IN NUMBER) RETURN NUMBER IS
    v_mca NUMBER;
    v_adjusted_av NUMBER;
BEGIN
    v_mca := get_market_conditions_adjustment();
    v_adjusted_av := p_av * v_mca;
    RETURN v_adjusted_av;
END calculate_adjusted_av;
/