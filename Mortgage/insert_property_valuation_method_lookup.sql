-- Appraisal Waiver plus Property Data Collection – Condition
INSERT INTO Property_Valuation_Method_Lookup (Valuation_Code, Valuation_Description, Detailed_Description) VALUES
('C', 'Appraisal Waiver plus Property Data Collection - Condition', 
 'The appraisal is waived with the requirement that certain property data is collected onsite by a licensed or certified appraiser or trained data collector to ensure the condition of the property meets the GSE’s requirements but is not used to validate the value of the property.');

-- Appraisal Waiver plus Property Data Collection – Value
INSERT INTO Property_Valuation_Method_Lookup (Valuation_Code, Valuation_Description, Detailed_Description) VALUES
('P', 'Appraisal Waiver plus Property Data Collection - Value', 
 'The appraisal is waived with the requirement that certain property data is collected onsite by a licensed or certified appraiser or trained data collector and used in a proprietary automated valuation model (AVM) to validate the value of the property.');

-- GSE Targeted Refinance Programs
INSERT INTO Property_Valuation_Method_Lookup (Valuation_Code, Valuation_Description, Detailed_Description) VALUES
('R', 'GSE Targeted Refinance', 
 'Programs implemented by the GSEs for targeted refinance products.');

-- Appraisal Waiver
INSERT INTO Property_Valuation_Method_Lookup (Valuation_Code, Valuation_Description, Detailed_Description) VALUES
('W', 'Appraisal Waiver', 
 'An appraisal is not required per applicable Selling Guide or negotiated terms.');

-- Other
INSERT INTO Property_Valuation_Method_Lookup (Valuation_Code, Valuation_Description, Detailed_Description) VALUES
('O', 'Other', 
 'Any property valuation method not provided for within the other enumerations.');
