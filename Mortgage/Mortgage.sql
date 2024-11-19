CREATE TABLE Reference_Pool (
    Reference_Pool_ID       VARCHAR2(10) PRIMARY KEY,  -- Unique identifier for the reference pool
    Pool_Name               VARCHAR2(100),            -- Name or description of the pool
    Acquisition_Date        DATE,                     -- Date the pool was acquired
    Total_UPB               NUMBER(12,2),             -- Total unpaid principal balance of the loans in the pool
    Number_of_Loans         NUMBER(10),               -- Total number of loans in the pool
    Performance_Status      VARCHAR2(20),             -- Status of the pool (e.g., Active, Closed)
    Created_By              VARCHAR2(50),             -- User who created the record
    Created_Date            DATE DEFAULT SYSDATE,     -- Date of record creation
    Modified_By             VARCHAR2(50),             -- User who last modified the record
    Modified_Date           DATE                      -- Date of last modification
);


CREATE TABLE Loan_old (
    Loan_ID                 VARCHAR2(12) PRIMARY KEY,  -- Unique identifier for each loan
    Reference_Pool_ID       VARCHAR2(10),              -- Foreign key to Reference_Pool
    Original_UPB            NUMBER(12,2),              -- Original unpaid principal balance
    Current_UPB             NUMBER(12,2),              -- Current unpaid principal balance
    Origination_Date        DATE,                      -- Loan origination date
    First_Payment_Date      DATE,                      -- First payment date by the borrower
    Loan_Term               NUMBER(3),                 -- Loan term in months
    Interest_Rate           NUMBER(5,3),               -- Interest rate of the loan
    Loan_Purpose            VARCHAR2(20),              -- Purpose of the loan (e.g., Purchase, Refinance)
    Property_Type           VARCHAR2(20),              -- Type of property (e.g., Single-family home)
    Loan_Type               VARCHAR2(20),              -- Fixed-rate, Adjustable-rate, etc.
    LTV                     NUMBER(5,2),               -- Loan-to-value ratio at origination
    CLTV                    NUMBER(5,2),               -- Combined loan-to-value ratio at origination
    Debt_to_Income          NUMBER(5,2),               -- Borrower’s debt-to-income ratio at origination
    Borrower_Credit_Score   NUMBER(3),                 -- Borrower’s credit score at origination
    Co_Borrower_Credit_Score NUMBER(3),                -- Co-borrower’s credit score at origination (if applicable)
    First_Time_Homebuyer    VARCHAR2(1),               -- Y/N indicator for first-time homebuyer
    Created_By              VARCHAR2(50),              -- User who created the record
    Created_Date            DATE DEFAULT SYSDATE,      -- Date of record creation
    Modified_By             VARCHAR2(50),              -- User who last modified the record
    Modified_Date           DATE,                      -- Date of last modification
    CONSTRAINT FK_Reference_Pool 
        FOREIGN KEY (Reference_Pool_ID) 
        REFERENCES Reference_Pool(Reference_Pool_ID)
);

CREATE TABLE Loan (
    Loan_ID                 VARCHAR2(12) PRIMARY KEY,
    Reference_Pool_ID       VARCHAR2(10),
    Original_UPB            NUMBER(12,2),
    Current_UPB             NUMBER(12,2),
    Origination_Date        DATE,
    First_Payment_Date      DATE,
    Loan_Term               NUMBER(3),
    Interest_Rate           NUMBER(5,3),
    Loan_Purpose            VARCHAR2(20),
    Property_Type           VARCHAR2(20),          -- New: To track the property type
    Occupancy_Status        VARCHAR2(20),          -- New: Primary residence, second home, or investment property
    Balloon_Indicator       VARCHAR2(1),           -- New: Y/N flag for balloon loans
    Interest_Only_Indicator VARCHAR2(1),           -- New: Y/N flag for interest-only loans
    Flood_Zone              VARCHAR2(20),          -- New: High-risk or low-risk flood zone classification
    Flood_Insurance         VARCHAR2(20),          -- New: Y/N flag for flood insurance
    LTV                     NUMBER(5,2),
    CLTV                    NUMBER(5,2),
    Debt_to_Income          NUMBER(5,2),
    Borrower_Credit_Score   NUMBER(3),
    Income_Documentation_Status VARCHAR2(20),      -- New: Sufficient/Insufficient income documentation
    Employment_Verification_Status VARCHAR2(20),   -- New: Employment verification status
    Prepayment_Penalty_Indicator VARCHAR2(1),
    Created_By              VARCHAR2(50),
    Created_Date            DATE DEFAULT SYSDATE,
    Modified_By             VARCHAR2(50),
    Modified_Date           DATE
);
ALTER TABLE Loan ADD (Loan_Type VARCHAR2(20));
ALTER TABLE Loan ADD (Refinanced_Loan_ID VARCHAR2(12));
ALTER TABLE Loan ADD (First_Time_Homebuyer VARCHAR2(1));
ALTER TABLE Loan ADD (Co_Borrower_Credit_Score NUMBER(3));
ALTER TABLE Loan ADD (Property_Valuation_Method VARCHAR2(1));
ALTER TABLE Loan ADD (Compliance_Flag VARCHAR2(1), Review_Date DATE);
ALTER TABLE Loan ADD (Eligibility_Status VARCHAR2(20));
ALTER TABLE Loan ADD (Foreclosure_Status VARCHAR2(20));
ALTER TABLE Loan ADD (Foreclosure_Start_Date DATE);


CREATE TABLE Loan_Performance (
    Performance_ID          NUMBER PRIMARY KEY,        -- Unique identifier for each performance record
    Loan_ID                 VARCHAR2(12),              -- Foreign key to Loan
    Reporting_Period        DATE,                      -- Month and year of the performance data
    Current_Interest_Rate   NUMBER(5,3),               -- Current interest rate for the loan
    Current_UPB             NUMBER(12,2),              -- Current unpaid principal balance
    Loan_Age                NUMBER(3),                 -- Age of the loan in months
    Delinquency_Status      VARCHAR2(2),               -- Delinquency status (e.g., 00 = Current, 01 = 30-59 days)
    Payment_Status          VARCHAR2(20),              -- Status of the loan (e.g., Current, Delinquent)
    Modification_Flag       VARCHAR2(1),               -- Y/N flag for loan modification
    Foreclosure_Flag        VARCHAR2(1),               -- Y/N flag for foreclosure
    Created_By              VARCHAR2(50),              -- User who created the record
    Created_Date            DATE DEFAULT SYSDATE,      -- Date of record creation
    Modified_By             VARCHAR2(50),              -- User who last modified the record
    Modified_Date           DATE,                      -- Date of last modification
    CONSTRAINT FK_Loan 
        FOREIGN KEY (Loan_ID) 
        REFERENCES Loan(Loan_ID)
);

CREATE TABLE Mapping_File (
    Mapping_ID              NUMBER PRIMARY KEY,        -- Unique identifier for each mapping record
    Original_Loan_ID        VARCHAR2(12),              -- Loan identifier before HARP refinancing
    Refinanced_Loan_ID      VARCHAR2(12),              -- Loan identifier after refinancing
    Refinance_Date          DATE,                      -- Date of the refinancing event
    Created_By              VARCHAR2(50),              -- User who created the record
    Created_Date            DATE DEFAULT SYSDATE,      -- Date of record creation
    Modified_By             VARCHAR2(50),              -- User who last modified the record
    Modified_Date           DATE,                      -- Date of last modification
    CONSTRAINT FK_Original_Loan 
        FOREIGN KEY (Original_Loan_ID) 
        REFERENCES Loan(Loan_ID),
    CONSTRAINT FK_Refinance_Loan 
        FOREIGN KEY (Refinanced_Loan_ID) 
        REFERENCES Loan(Loan_ID)
);


CREATE TABLE Data_Ingestion_Log (
    Log_ID                  NUMBER PRIMARY KEY,        -- Unique log entry identifier
    Process_Date            DATE DEFAULT SYSDATE,      -- Date and time the ingestion occurred
    File_Name               VARCHAR2(100),             -- Name of the file being processed
    Status                  VARCHAR2(20),              -- Status of the data ingestion (Success, Error)
    Error_Message           VARCHAR2(4000),            -- Error message, if any
    Created_By              VARCHAR2(50),              -- User who initiated the data ingestion
    Created_Date            DATE DEFAULT SYSDATE,      -- Date of record creation
	Modified_By              VARCHAR2(50),               -- User who last modified the record
    Modified_Date            DATE                       -- Last modification date
);

CREATE TABLE Loan_Staging (
    Loan_ID                 VARCHAR2(12),              -- Loan identifier
    Reference_Pool_ID       VARCHAR2(10),              -- Reference pool identifier
    Original_UPB            NUMBER(12,2),              -- Original unpaid principal balance
    Current_UPB             NUMBER(12,2),              -- Current unpaid principal balance
    Origination_Date        DATE,                      -- Origination date of the loan
    First_Payment_Date      DATE,                      -- First payment date
    Loan_Term               NUMBER(3),                 -- Loan term in months
    Interest_Rate           NUMBER(5,3),               -- Interest rate of the loan
    Loan_Purpose            VARCHAR2(20),              -- Loan purpose
    Property_Type           VARCHAR2(20),              -- Property type
    Loan_Type               VARCHAR2(20),              -- Loan type
    LTV                     NUMBER(5,2),               -- Loan-to-value ratio
    CLTV                    NUMBER(5,2),               -- Combined loan-to-value ratio
    Debt_to_Income          NUMBER(5,2),               -- Debt-to-income ratio
    Borrower_Credit_Score   NUMBER(3),                 -- Borrower credit score
    Co_Borrower_Credit_Score NUMBER(3),                -- Co-borrower credit score
    First_Time_Homebuyer    VARCHAR2(1)                -- First-time homebuyer flag
);

CREATE TABLE Loan_Validation_Errors (
    Loan_ID                 VARCHAR2(12),        -- Loan identifier
    Error_Type              VARCHAR2(50),        -- Type of error (e.g., Data Validation, Business Rule)
    Error_Severity          VARCHAR2(10),        -- Severity of the error (e.g., Critical, Major, Minor)
    Field_Name              VARCHAR2(50),        -- Field where the error occurred (e.g., LTV, Interest_Rate)
    Validation_Rule         VARCHAR2(200),       -- The rule that was violated (e.g., LTV must be ≤ 97%)
    Error_Message           VARCHAR2(4000),      -- Detailed error message
    User_Action_Required    VARCHAR2(3),         -- Y/N - Does the error require manual intervention?
    Error_Date              DATE DEFAULT SYSDATE -- Date when the error was logged
);



CREATE TABLE Property (
    Property_ID              VARCHAR2(12) PRIMARY KEY,    -- Unique identifier for the property
    Loan_ID                  VARCHAR2(12),               -- Foreign key linking to the Loan entity
    Property_Type            VARCHAR2(20),               -- Type of property (e.g., Single-family, Condominium)
    Occupancy_Status         VARCHAR2(20),               -- Occupancy status (e.g., Primary Residence, Second Home, Investor)
    Property_Condition       VARCHAR2(20),               -- Property condition (e.g., Good, Fair, Poor)
    Flood_Zone               VARCHAR2(20),               -- Flood zone classification (e.g., High-Risk, Low-Risk)
    Flood_Insurance          VARCHAR2(3),                -- Y/N flag indicating whether flood insurance is in place
    Created_By               VARCHAR2(50),               -- User who created the record
    Created_Date             DATE DEFAULT SYSDATE,       -- Record creation date
    Modified_By              VARCHAR2(50),               -- User who last modified the record
    Modified_Date            DATE,                       -- Last modification date
    CONSTRAINT FK_Loan_Property FOREIGN KEY (Loan_ID)
    REFERENCES Loan(Loan_ID)                              -- Foreign key reference to the Loan entity
);

CREATE TABLE Borrower (
    Borrower_ID              VARCHAR2(12) PRIMARY KEY,    -- Unique identifier for the borrower
    Loan_ID                  VARCHAR2(12),               -- Foreign key linking to the Loan entity
    Borrower_Credit_Score    NUMBER(3),                  -- Borrower's credit score
    Co_Borrower_Credit_Score NUMBER(3),                  -- Co-borrower's credit score (if applicable)
    Debt_to_Income           NUMBER(5,2),                -- Borrower's debt-to-income ratio (DTI)
    Income_Documentation_Status VARCHAR2(20),            -- Sufficient/Insufficient income documentation status
    Employment_Verification_Status VARCHAR2(20),         -- Verified/Not Verified employment status
    Created_By               VARCHAR2(50),               -- User who created the record
    Created_Date             DATE DEFAULT SYSDATE,       -- Record creation date
    Modified_By              VARCHAR2(50),               -- User who last modified the record
    Modified_Date            DATE,                       -- Last modification date
    CONSTRAINT FK_Loan_Borrower FOREIGN KEY (Loan_ID)
    REFERENCES Loan(Loan_ID)                              -- Foreign key reference to the Loan entity
);

CREATE TABLE Loan_Modification (
    Modification_ID        VARCHAR2(12) PRIMARY KEY,   -- Unique identifier for the modification event
    Loan_ID                VARCHAR2(12),              -- Foreign key linking to the Loan entity
    Modification_Flag      VARCHAR2(1),               -- Y/N flag indicating whether the loan has been modified
    Modification_Date      DATE,                      -- Date of the loan modification
    Modified_Interest_Rate NUMBER(5,3),               -- New interest rate after modification (if applicable)
    Modified_UPB           NUMBER(12,2),              -- New unpaid principal balance after modification (if applicable)
    Principal_Forgiveness  NUMBER(12,2),              -- Amount of principal forgiven during modification (if applicable)
    Created_By             VARCHAR2(50),              -- User who created the record
    Created_Date           DATE DEFAULT SYSDATE,      -- Date of record creation
    Modified_By            VARCHAR2(50),              -- User who last modified the record
    Modified_Date          DATE,                      -- Date of last modification
    CONSTRAINT FK_Loan_Modification FOREIGN KEY (Loan_ID)
    REFERENCES Loan(Loan_ID)                          -- Foreign key reference to the Loan entity
);

CREATE SEQUENCE Data_Ingestion_Log_Seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE;

CREATE TABLE Loan_Status (
    Status_ID           NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,  -- Unique identifier for each status record
    Loan_ID             VARCHAR2(12) NOT NULL,                                -- Foreign key linking to the Loan entity
    Loan_Status         VARCHAR2(20),                                         -- Status of the loan (e.g., Active, Delinquent, Foreclosed)
    Delinquency_Flag    VARCHAR2(1) CHECK (Delinquency_Flag IN ('Y', 'N')),   -- Y/N flag indicating delinquency
    Foreclosure_Flag    VARCHAR2(1) CHECK (Foreclosure_Flag IN ('Y', 'N')),   -- Y/N flag indicating if loan is in foreclosure
    Status_Date         DATE,                                                 -- Date when the status was recorded
    Created_By          VARCHAR2(50),                                         -- User who created the record
    Created_Date        DATE DEFAULT SYSDATE,                                 -- Date of record creation
    Modified_By         VARCHAR2(50),                                         -- User who last modified the record
    Modified_Date       DATE                                                  -- Date of last modification
);

CREATE TABLE external_loan_source_file (
    Loan_ID                 VARCHAR2(12),               -- Loan identifier
    Reference_Pool_ID       VARCHAR2(10),               -- Reference pool identifier
    Original_UPB            NUMBER(12,2),               -- Original unpaid principal balance
    Current_UPB             NUMBER(12,2),               -- Current unpaid principal balance
    Origination_Date        DATE,                       -- Origination date of the loan
    First_Payment_Date      DATE,                       -- First payment date
    Loan_Term               NUMBER(3),                  -- Loan term in months
    Interest_Rate           NUMBER(5,3),                -- Interest rate of the loan
    Loan_Purpose            VARCHAR2(20),               -- Purpose of the loan
    Property_Type           VARCHAR2(20),               -- Property type
    Loan_Type               VARCHAR2(20),               -- Loan type
    LTV                     NUMBER(5,2),                -- Loan-to-value ratio
    CLTV                    NUMBER(5,2),                -- Combined loan-to-value ratio
    Debt_to_Income          NUMBER(5,2),                -- Debt-to-income ratio
    Borrower_Credit_Score   NUMBER(3),                  -- Borrower’s credit score
    Co_Borrower_Credit_Score NUMBER(3),                 -- Co-borrower’s credit score
    First_Time_Homebuyer    VARCHAR2(1)                 -- Flag for first-time homebuyers
);

CREATE TABLE Property_Valuation_Method_Lookup (
    Valuation_Code         VARCHAR2(1) PRIMARY KEY,  -- Code for valuation method (e.g., A, C, P, R, W, O)
    Valuation_Description  VARCHAR2(200),           -- Short description of the valuation method
    Detailed_Description   CLOB                     -- Detailed description of the valuation method
);

INSERT INTO Property_Valuation_Method_Lookup (Valuation_Code, Valuation_Description, Detailed_Description) VALUES
('A', 'Appraisal', 'The property value obtained through an appraisal that was completed by a licensed or certified appraiser.');
-- Add other entries for C, P, R, W, O

CREATE TABLE Eligibility_Status_Lookup (
    Status_Code      VARCHAR2(20) PRIMARY KEY,  -- Short status code
    Status_Description VARCHAR2(100)            -- Detailed description
);

-- Insert a few sample status codes
INSERT INTO Eligibility_Status_Lookup (Status_Code, Status_Description) VALUES 
('GSE_REF_ELIG', 'Eligible for GSE Targeted Refinance');
INSERT INTO Eligibility_Status_Lookup (Status_Code, Status_Description) VALUES 
('MANUAL_REVIEW', 'Requires manual review');
-- Add other statuses as needed

CREATE TABLE Appraisal_Documents (
    Document_ID          NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,  -- Unique identifier for each document
    Loan_ID              VARCHAR2(12) NOT NULL,                                -- Foreign key linking to Loan table
    Appraisal_Date       DATE,                                                 -- Date of the appraisal
    Appraiser_Name       VARCHAR2(100),                                        -- Name of the appraiser
    Appraisal_Value      NUMBER(12,2),                                         -- Appraised value of the property
    Document_Type        VARCHAR2(50),                                         -- Type of document (e.g., Initial, Final)
    Document_Status      VARCHAR2(20) CHECK (Document_Status IN ('Pending', 'Approved', 'Rejected')), -- Status of the document
    Created_By           VARCHAR2(50),                                         -- User who created the record
    Created_Date         DATE DEFAULT SYSDATE,                                 -- Date of record creation
    Modified_By          VARCHAR2(50),                                         -- User who last modified the record
    Modified_Date        DATE                                                  -- Date of last modification
);

-- Optional: Add an index on Loan_ID to optimize existence checks
CREATE INDEX idx_appraisal_documents_loan_id ON Appraisal_Documents (Loan_ID);


CREATE TABLE Property_Data_Collection (
    Collection_ID          NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, -- Unique identifier for each record
    Loan_ID                VARCHAR2(12) NOT NULL,                               -- Foreign key linking to Loan table
    Collection_Date        DATE,                                                -- Date of the property data collection
    Data_Collector_Name    VARCHAR2(100),                                       -- Name of the data collector
    Data_Collection_Type   VARCHAR2(50),                                        -- Type of data collection (e.g., Condition, Value)
    AVM_Validation_Flag    VARCHAR2(1) CHECK (AVM_Validation_Flag IN ('Y', 'N')), -- Y/N flag for AVM validation requirement
    Data_Status            VARCHAR2(20) CHECK (Data_Status IN ('Pending', 'Complete', 'Rejected')), -- Status of data collection
    Created_By             VARCHAR2(50),                                        -- User who created the record
    Created_Date           DATE DEFAULT SYSDATE,                                -- Date of record creation
    Modified_By            VARCHAR2(50),                                        -- User who last modified the record
    Modified_Date          DATE                                                 -- Date of last modification
);

-- Optional: Add an index on Loan_ID to optimize existence checks
CREATE INDEX idx_property_data_collection_loan_id ON Property_Data_Collection (Loan_ID);

CREATE TABLE Waiver_Approval (
    Waiver_ID              NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, -- Unique identifier for each waiver record
    Loan_ID                VARCHAR2(12) NOT NULL,                               -- Foreign key linking to Loan table
    Waiver_Type            VARCHAR2(50),                                        -- Type of waiver (e.g., Appraisal Waiver)
    Approval_Date          DATE,                                                -- Date of waiver approval
    Approved_By            VARCHAR2(100),                                       -- Name of the person or entity approving the waiver
    Waiver_Status          VARCHAR2(20) CHECK (Waiver_Status IN ('Approved', 'Rejected', 'Pending')), -- Status of the waiver
    Created_By             VARCHAR2(50),                                        -- User who created the record
    Created_Date           DATE DEFAULT SYSDATE,                                -- Date of record creation
    Modified_By            VARCHAR2(50),                                        -- User who last modified the record
    Modified_Date          DATE                                                 -- Date of last modification
);

-- Optional: Add an index on Loan_ID to optimize existence checks
CREATE INDEX idx_waiver_approval_loan_id ON Waiver_Approval (Loan_ID);

CREATE TABLE Foreclosure_Costs (
    Cost_ID                 NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, -- Unique ID for each cost entry
    Loan_ID                 VARCHAR2(12) NOT NULL,                               -- Foreign key to Loan table
    Cost_Type               VARCHAR2(50),                                        -- Type of cost (e.g., Legal Fees, Maintenance)
    Cost_Amount             NUMBER(12,2),                                        -- Cost amount
    Cost_Date               DATE,                                                -- Date the cost was incurred
    Cost_Status             VARCHAR2(20) CHECK (Cost_Status IN ('Pending', 'Paid', 'Disputed')), -- Status of the cost
    Created_By              VARCHAR2(50),                                        -- User who created the record
    Created_Date            DATE DEFAULT SYSDATE,                                -- Date of record creation
    Modified_By             VARCHAR2(50),                                        -- User who last modified the record
    Modified_Date           DATE                                                 -- Date of last modification
);

-- Optional: Index on Loan_ID to optimize queries
CREATE INDEX idx_foreclosure_costs_loan_id ON Foreclosure_Costs (Loan_ID);

CREATE TABLE Refinance_Documents (
    Document_ID           NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,  -- Unique identifier for each document
    Loan_ID               VARCHAR2(12) NOT NULL,                                -- Foreign key linking to Loan table
    Document_Type         VARCHAR2(50),                                         -- Type of refinance document (e.g., Income Verification, Appraisal)
    Document_Status       VARCHAR2(20) CHECK (Document_Status IN ('Pending', 'Approved', 'Rejected')),  -- Status of the document
    Created_By            VARCHAR2(50),                                         -- User who created the record
    Created_Date          DATE DEFAULT SYSDATE,                                 -- Date of record creation
    Modified_By           VARCHAR2(50),                                         -- User who last modified the record
    Modified_Date         DATE                                                  -- Date of last modification
);

-- Optional: Add an index on Loan_ID to optimize existence checks
CREATE INDEX idx_refinance_documents_loan_id ON Refinance_Documents (Loan_ID);

