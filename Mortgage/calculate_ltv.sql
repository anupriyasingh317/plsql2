CREATE OR REPLACE FUNCTION calculate_ltv (
    p_original_loan_amount NUMBER,   -- Original loan amount
    p_property_value       NUMBER    -- Appraised property value or purchase price
) RETURN NUMBER IS
    v_ltv NUMBER;  -- Variable to hold the calculated LTV value
BEGIN
    -- Check for valid inputs to avoid division by zero
    IF p_property_value > 0 THEN
        -- Calculate LTV
        v_ltv := (p_original_loan_amount / p_property_value) * 100;
    ELSE
        -- If property value is invalid (e.g., zero or negative), return NULL
        v_ltv := NULL;
    END IF;

    -- Return the calculated LTV
    RETURN v_ltv;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any unexpected errors and return NULL
        DBMS_OUTPUT.PUT_LINE('Error calculating LTV: ' || SQLERRM);
        RETURN NULL;
END calculate_ltv;
/
