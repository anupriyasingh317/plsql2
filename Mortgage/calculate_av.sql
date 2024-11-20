CREATE OR REPLACE FUNCTION calculate_av(p_property_id IN VARCHAR2) RETURN NUMBER IS
    v_av NUMBER;
    TYPE ComparableRec IS RECORD (
        Sale_Price   NUMBER,
        Adjustments  NUMBER
    );
    TYPE ComparableTable IS TABLE OF ComparableRec INDEX BY PLS_INTEGER;
    v_comparables ComparableTable;
    v_total_adjusted_price NUMBER := 0;
    v_comparable_count     NUMBER := 0;
BEGIN
    -- Retrieve comparable sales data for the property
    SELECT cs.Sale_Price, cs.Adjustments
    BULK COLLECT INTO v_comparables
    FROM Comparable_Sales cs
    WHERE cs.Property_ID = p_property_id;

    -- Calculate the total adjusted price
    FOR i IN 1 .. v_comparables.COUNT LOOP
        v_total_adjusted_price := v_total_adjusted_price + (v_comparables(i).Sale_Price + v_comparables(i).Adjustments);
        v_comparable_count := v_comparable_count + 1;
    END LOOP;

    IF v_comparable_count > 0 THEN
        v_av := v_total_adjusted_price / v_comparable_count;
    ELSE
        v_av := NULL;  -- No comparables found
    END IF;

    RETURN v_av;
END calculate_av;
/
