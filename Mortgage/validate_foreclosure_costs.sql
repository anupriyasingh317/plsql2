CREATE OR REPLACE PROCEDURE validate_foreclosure_costs AS
    v_invalid_count NUMBER := 0;
    v_dummy NUMBER;  -- Variable for SELECT INTO checks
    v_total_cost NUMBER(12, 2); -- Variable to store total foreclosure costs
    v_max_cost_limit NUMBER(12, 2) := 10000; -- Hypothetical maximum allowed cost limit per cost type
BEGIN
    -- Step 1: Validate Total Foreclosure Costs do not exceed the threshold per cost type
    FOR loan_rec IN (
        SELECT Loan_ID, Foreclosure_Status
        FROM Loan
        WHERE Foreclosure_Status = 'Active'
    ) LOOP
        -- Iterate through each type of cost to validate limits
        FOR cost_type_rec IN (
            SELECT DISTINCT Cost_Type 
            FROM Foreclosure_Costs
            WHERE Loan_ID = loan_rec.Loan_ID
        ) LOOP
            -- Calculate total cost per cost type
            BEGIN
                SELECT SUM(Cost_Amount)
                INTO v_total_cost
                FROM Foreclosure_Costs
                WHERE Loan_ID = loan_rec.Loan_ID
                  AND Cost_Type = cost_type_rec.Cost_Type;

                -- Check if total cost exceeds maximum allowed limit
                IF v_total_cost > v_max_cost_limit THEN
                    INSERT INTO Loan_Validation_Errors (
                        Loan_ID, Error_Type, Error_Severity, Field_Name, 
                        Validation_Rule, Error_Message, User_Action_Required, Error_Date
                    ) VALUES (
                        loan_rec.Loan_ID, 'Foreclosure Cost Compliance', 'Critical', cost_type_rec.Cost_Type,
                        'Total cost must not exceed ' || v_max_cost_limit,
                        'Total foreclosure cost for type "' || cost_type_rec.Cost_Type || '" exceeds limit', 'Y', SYSDATE
                    );
                    v_invalid_count := v_invalid_count + 1;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- Log if no cost entry is found for the loan and cost type
                    INSERT INTO Loan_Validation_Errors (
                        Loan_ID, Error_Type, Error_Severity, Field_Name, 
                        Validation_Rule, Error_Message, User_Action_Required, Error_Date
                    ) VALUES (
                        loan_rec.Loan_ID, 'Foreclosure Cost Compliance', 'Major', cost_type_rec.Cost_Type,
                        'Required foreclosure cost type is missing',
                        'No cost found for type "' || cost_type_rec.Cost_Type || '"', 'Y', SYSDATE
                    );
                    v_invalid_count := v_invalid_count + 1;
            END;
        END LOOP;

        -- Step 2: Validate if foreclosure costs are fully paid before marking "Completed"
        IF loan_rec.Foreclosure_Status = 'Foreclosure Completed' THEN
            BEGIN
                SELECT COUNT(*)
                INTO v_dummy
                FROM Foreclosure_Costs
                WHERE Loan_ID = loan_rec.Loan_ID
                  AND Cost_Status <> 'Paid';

                IF v_dummy > 0 THEN
                    INSERT INTO Loan_Validation_Errors (
                        Loan_ID, Error_Type, Error_Severity, Field_Name, 
                        Validation_Rule, Error_Message, User_Action_Required, Error_Date
                    ) VALUES (
                        loan_rec.Loan_ID, 'Foreclosure Completion Validation', 'Critical', 'Cost_Status',
                        'All foreclosure costs must be fully paid before foreclosure completion',
                        'Unpaid foreclosure costs found for Loan', 'Y', SYSDATE
                    );
                    v_invalid_count := v_invalid_count + 1;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- Log if no cost entry is found for the loan while marking foreclosure completed
                    INSERT INTO Loan_Validation_Errors (
                        Loan_ID, Error_Type, Error_Severity, Field_Name, 
                        Validation_Rule, Error_Message, User_Action_Required, Error_Date
                    ) VALUES (
                        loan_rec.Loan_ID, 'Foreclosure Completion Validation', 'Critical', 'Cost_Status',
                        'No foreclosure costs found, but foreclosure marked as completed',
                        'Foreclosure completion check failed', 'Y', SYSDATE
                    );
                    v_invalid_count := v_invalid_count + 1;
            END;
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total invalid foreclosure cost entries found: ' || v_invalid_count);
END validate_foreclosure_costs;
/
