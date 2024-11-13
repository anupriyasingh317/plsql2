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
    Refinance_Loan_ID       VARCHAR2(12),              -- Loan identifier after refinancing
    Refinance_Date          DATE,                      -- Date of the refinancing event
    Created_By              VARCHAR2(50),              -- User who created the record
    Created_Date            DATE DEFAULT SYSDATE,      -- Date of record creation
    Modified_By             VARCHAR2(50),              -- User who last modified the record
    Modified_Date           DATE,                      -- Date of last modification
    CONSTRAINT FK_Original_Loan 
        FOREIGN KEY (Original_Loan_ID) 
        REFERENCES Loan(Loan_ID),
    CONSTRAINT FK_Refinance_Loan 
        FOREIGN KEY (Refinance_Loan_ID) 
        REFERENCES Loan(Loan_ID)
);


CREATE TABLE Data_Ingestion_Log (
    Log_ID                  NUMBER PRIMARY KEY,        -- Unique log entry identifier
    Process_Date            DATE DEFAULT SYSDATE,      -- Date and time the ingestion occurred
    File_Name               VARCHAR2(100),             -- Name of the file being processed
    Status                  VARCHAR2(20),              -- Status of the data ingestion (Success, Error)
    Error_Message           VARCHAR2(4000),            -- Error message, if any
    Created_By              VARCHAR2(50),              -- User who initiated the data ingestion
    Created_Date            DATE DEFAULT SYSDATE       -- Date of record creation
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


