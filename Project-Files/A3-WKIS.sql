--Database Programming CPRG-307--
--Group 7: Seoungho Back, Saihaj Mann, Bhavya, Liam Marrie--
--Assignment 3: Develop and Test a Coded Solution with Exception Handlers--

--server output on
SET SERVEROUTPUT ON;

DECLARE

--declare variables
LV_TRANSACTION_NO NEW_TRANSACTIONS.TRANSACTION_NO%TYPE;

DEBIT_TOTAL NUMBER := 0;

CREDIT_TOTAL NUMBER := 0;

TRANS_TYPE ACCOUNT_TYPE.DEFAULT_TRANS_TYPE%TYPE;

CHANGE_BY NUMBER;

V_ERROR_MSG VARCHAR2(200);

credits_not_equal_debits Exception;

Invalid_transaction_type Exception;

negative_numbers_exception Exception;

non_existing_account_exception Exception;

non_existing_account number := 0;

--cursor to fetch distinct transactions
CURSOR CUR_TRANSACTION_HISTORY IS
SELECT
    DISTINCT TRANSACTION_NO,
    TRANSACTION_DATE,
    DESCRIPTION
FROM
    NEW_TRANSACTIONS
WHERE
    TRANSACTION_NO IS NOT NULL
ORDER BY
    TRANSACTION_NO;


--get the current transaction, to use for error handling
TYPE TransactionDetailRecord IS RECORD (
        ACCOUNT_NO         NEW_TRANSACTIONS.ACCOUNT_NO%TYPE,
        TRANSACTION_TYPE   NEW_TRANSACTIONS.TRANSACTION_TYPE%TYPE,
        TRANSACTION_AMOUNT NEW_TRANSACTIONS.TRANSACTION_AMOUNT%TYPE
    );
CURRENT_REC_DETAIL TransactionDetailRecord;

--cursor to fetch transaction details for the current transaction
CURSOR CUR_TRANSACTION_DETAILS(LV_TRANSACTION_NO NUMBER) IS
SELECT
    ACCOUNT_NO,
    TRANSACTION_TYPE,
    TRANSACTION_AMOUNT
FROM
    NEW_TRANSACTIONS
WHERE
    TRANSACTION_NO = LV_TRANSACTION_NO;

BEGIN
 --loop through distinct transactions
    FOR REC_TRANSACTION IN CUR_TRANSACTION_HISTORY LOOP

        LV_TRANSACTION_NO := REC_TRANSACTION.TRANSACTION_NO;
        
        BEGIN
        DEBIT_TOTAL := 0;
        CREDIT_TOTAL := 0;

        INSERT INTO TRANSACTION_HISTORY
            VALUES(
                LV_TRANSACTION_NO,
                REC_TRANSACTION.TRANSACTION_DATE,
                REC_TRANSACTION.DESCRIPTION
            );
 --loop througb transactions details  for curr transaction
        FOR REC_DETAIL IN CUR_TRANSACTION_DETAILS(LV_TRANSACTION_NO) LOOP
            CURRENT_REC_DETAIL.ACCOUNT_NO := REC_DETAIL.ACCOUNT_NO;
            CURRENT_REC_DETAIL.TRANSACTION_TYPE := REC_DETAIL.TRANSACTION_TYPE;
            CURRENT_REC_DETAIL.TRANSACTION_AMOUNT := REC_DETAIL.TRANSACTION_AMOUNT;

            IF REC_DETAIL.TRANSACTION_AMOUNT < 0 THEN
                --handle exception for negative transaction
                Raise negative_numbers_exception;
            END IF;

            IF REC_DETAIL.TRANSACTION_TYPE = 'D' THEN
                DEBIT_TOTAL := DEBIT_TOTAL + REC_DETAIL.TRANSACTION_AMOUNT;
            ELSIF REC_DETAIL.TRANSACTION_TYPE = 'C' THEN
                CREDIT_TOTAL := CREDIT_TOTAL + REC_DETAIL.TRANSACTION_AMOUNT;
            ELSE
 --handle invalid transaction type
                Raise Invalid_transaction_type;
            END IF;

            select count(*) into non_existing_account
            from account
            where account.account_no = REC_DETAIL.account_no;

            if non_existing_account < 0 then
                non_existing_account := REC_DETAIL.account_no;
                Raise non_existing_account_exception;
            end if;

 --retrieve the default transaction type for account
            SELECT
                AT.DEFAULT_TRANS_TYPE INTO TRANS_TYPE
            FROM
                ACCOUNT A
                JOIN ACCOUNT_TYPE AT
                ON A.ACCOUNT_TYPE_CODE = AT.ACCOUNT_TYPE_CODE
            WHERE
                A.ACCOUNT_NO = REC_DETAIL.ACCOUNT_NO;
 --determine amount to adjust acc balance by
            CHANGE_BY := CASE
                WHEN TRANS_TYPE = REC_DETAIL.TRANSACTION_TYPE THEN
                    REC_DETAIL.TRANSACTION_AMOUNT
                ELSE
                    -REC_DETAIL.TRANSACTION_AMOUNT
            END;
 --update account balance
            UPDATE ACCOUNT A
            SET
                A.ACCOUNT_BALANCE = A.ACCOUNT_BALANCE + CHANGE_BY
            WHERE
                A.ACCOUNT_NO = REC_DETAIL.ACCOUNT_NO;
 --insert transaction details
            INSERT INTO TRANSACTION_DETAIL
                VALUES(
                REC_DETAIL.ACCOUNT_NO,
                LV_TRANSACTION_NO,
                REC_DETAIL.TRANSACTION_TYPE,
                REC_DETAIL.TRANSACTION_AMOUNT
            );
        END LOOP;
 --check debits equal credits before committing
        IF DEBIT_TOTAL = CREDIT_TOTAL THEN
--delete the transaction
            DELETE FROM NEW_TRANSACTIONS
            WHERE
                TRANSACTION_NO = LV_TRANSACTION_NO;
 --commit deletion
            COMMIT;
        ELSE
 --if debits != credits rollback and log the error
            Raise credits_not_equal_debits;
            
        END IF;

        Exception

            
            When non_existing_account_exception THEN
                ROLLBACK;
                V_ERROR_MSG := 'the following account does not exist ' || TO_CHAR(non_existing_account);
                INSERT INTO WKIS_ERROR_LOG (
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;

            When negative_numbers_exception THEN
                ROLLBACK;
                V_ERROR_MSG := 'negative transaction amount: ' || TO_CHAR(LV_TRANSACTION_NO);
                INSERT INTO WKIS_ERROR_LOG (
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;
            When Invalid_transaction_type THEN
                ROLLBACK;
                V_ERROR_MSG := 'invalid transaction type: ' || CURRENT_REC_DETAIL.TRANSACTION_TYPE;
                INSERT INTO WKIS_ERROR_LOG (
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;
            WHEN credits_not_equal_debits THEN
                ROLLBACK;
                V_ERROR_MSG := 'debit and credit totals do not match for transaction history: ' || TO_CHAR(LV_TRANSACTION_NO);
                INSERT INTO WKIS_ERROR_LOG (
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;
            WHEN DUP_VAL_ON_INDEX THEN
                ROLLBACK;
            --handle duplicate transaction numbers
                V_ERROR_MSG := 'duplicate transaction number';
                INSERT INTO WKIS_ERROR_LOG(
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
             --handle missing transactions nums
                V_ERROR_MSG := 'missing transaction number';
                INSERT INTO WKIS_ERROR_LOG(
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    null,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;
            WHEN OTHERS THEN
                ROLLBACK;
             --handle all other errors
                V_ERROR_MSG := 'unknown error: '
                       || SQLERRM;
                    INSERT INTO WKIS_ERROR_LOG(
                    TRANSACTION_NO,
                    transaction_date,
                    description,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    REC_TRANSACTION.transaction_date,
                    REC_TRANSACTION.description,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                COMMIT;
    END;
    END LOOP;

--I beleive we need to move exceptions up so that it will generate error, but keep working
EXCEPTION
    
    WHEN NO_DATA_FOUND THEN
 --handle missing transactions nums
        V_ERROR_MSG := 'missing transaction number';
        INSERT INTO WKIS_ERROR_LOG(
            ERROR_MSG
        ) VALUES (
            V_ERROR_MSG
        );
        DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);

    
    --WHEN OTHERS THEN -- this is very wrong, espicailly when there is a secound one
    When TOO_MANY_ROWS THEN --change to its actual one later
 --handle negative transaction amounts
        V_ERROR_MSG := 'negative transaction amount';
        INSERT INTO WKIS_ERROR_LOG(
            TRANSACTION_NO,
            ERROR_MSG
        )VALUES(
            LV_TRANSACTION_NO,
            V_ERROR_MSG
        );
        DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
    WHEN DUP_VAL_ON_INDEX THEN
 --handle duplicate transaction numbers
        V_ERROR_MSG := 'duplicate transaction number';
        INSERT INTO WKIS_ERROR_LOG(
            TRANSACTION_NO,
            ERROR_MSG
        )VALUES(
            LV_TRANSACTION_NO,
            V_ERROR_MSG
        );
        DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
    WHEN OTHERS THEN
 --handle all other errors
        V_ERROR_MSG := 'unknown error: '
                       || SQLERRM;
        INSERT INTO WKIS_ERROR_LOG(
            TRANSACTION_NO,
            ERROR_MSG
        )VALUES(
            LV_TRANSACTION_NO,
            V_ERROR_MSG
        );
        DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
        ROLLBACK;
END;
/

--set serveroutput off;
--select * from wkis_error_log;

