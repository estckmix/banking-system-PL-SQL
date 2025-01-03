-- Step 1: Create necessary tables to store account information, transactions, and login attempts.
-- Accounts table to store user information
CREATE TABLE accounts (
    account_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    account_name VARCHAR2(100),
    password_hash VARCHAR2(256),
    balance NUMBER(12, 2) DEFAULT 0,
    failed_attempts NUMBER DEFAULT 0,
    account_locked CHAR(1) DEFAULT 'N' -- 'Y' if account is locked, 'N' otherwise
);

-- Transactions table to log fund transfer history
CREATE TABLE transactions (
    transaction_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    source_account_id NUMBER,
    target_account_id NUMBER,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount NUMBER(12, 2),
    FOREIGN KEY (source_account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (target_account_id) REFERENCES accounts(account_id)
);

-- Step 2: Define a procedure to create a new account with password encryption
CREATE OR REPLACE PROCEDURE create_account (
    p_account_name IN VARCHAR2,
    p_password IN VARCHAR2
) AS
BEGIN
    INSERT INTO accounts (account_name, password_hash)
    VALUES (p_account_name, DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(p_password), 3)); -- 3 = SHA-256
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Account created successfully.');
END;
/

-- Step 3: Define a function for user login and account validation
CREATE OR REPLACE FUNCTION login_account (
    p_account_name IN VARCHAR2,
    p_password IN VARCHAR2
) RETURN VARCHAR2 AS
    v_account_id NUMBER;
    v_password_hash VARCHAR2(256);
    v_account_locked CHAR(1);
BEGIN
    SELECT account_id, password_hash, account_locked
    INTO v_account_id, v_password_hash, v_account_locked
    FROM accounts
    WHERE account_name = p_account_name;

    -- Check if account is locked
    IF v_account_locked = 'Y' THEN
        RETURN 'Account is locked due to multiple failed login attempts.';
    END IF;

    -- Validate password
    IF v_password_hash = DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(p_password), 3) THEN
        -- Reset failed attempts on successful login
        UPDATE accounts SET failed_attempts = 0 WHERE account_id = v_account_id;
        COMMIT;
        RETURN 'Login successful.';
    ELSE
        -- Increment failed attempts and lock account if threshold reached
        UPDATE accounts
        SET failed_attempts = failed_attempts + 1,
            account_locked = CASE WHEN failed_attempts + 1 >= 3 THEN 'Y' ELSE 'N' END
        WHERE account_id = v_account_id;
        COMMIT;
        RETURN 'Invalid credentials. Account may be locked after 3 failed attempts.';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'Account does not exist.';
END;
/

-- Step 4: Define a procedure for fund transfers
CREATE OR REPLACE PROCEDURE transfer_funds (
    p_source_account_id IN NUMBER,
    p_target_account_id IN NUMBER,
    p_amount IN NUMBER
) AS
    v_source_balance NUMBER;
BEGIN
    -- Check source account balance
    SELECT balance INTO v_source_balance FROM accounts WHERE account_id = p_source_account_id;

    IF v_source_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient balance.');
    END IF;

    -- Deduct amount from source account
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_source_account_id;

    -- Add amount to target account
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_target_account_id;

    -- Log the transaction
    INSERT INTO transactions (source_account_id, target_account_id, amount)
    VALUES (p_source_account_id, p_target_account_id, p_amount);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Funds transferred successfully.');
END;
/

-- Step 5: Define a function to check account balance
CREATE OR REPLACE FUNCTION check_balance (
    p_account_id IN NUMBER
) RETURN NUMBER AS
    v_balance NUMBER;
BEGIN
    SELECT balance INTO v_balance FROM accounts WHERE account_id = p_account_id;
    RETURN v_balance;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Account not found.');
END;
/

-- Step 6: Define a procedure to view transaction history
CREATE OR REPLACE PROCEDURE view_transaction_history (
    p_account_id IN NUMBER
) AS
BEGIN
    FOR rec IN (
        SELECT transaction_date, source_account_id, target_account_id, amount
        FROM transactions
        WHERE source_account_id = p_account_id OR target_account_id = p_account_id
        ORDER BY transaction_date DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Date: ' || rec.transaction_date || 
                             ', Source: ' || rec.source_account_id ||
                             ', Target: ' || rec.target_account_id ||
                             ', Amount: ' || rec.amount);
    END LOOP;
END;
/

-- Now the banking system is ready with account creation, login, fund transfer, balance inquiry, and transaction history features.
-- Security is implemented via password encryption and account locking for failed login attempts.
