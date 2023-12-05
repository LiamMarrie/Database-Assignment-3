--Database Programming CPRG-307--
--Group 7: Seoungho Back, Saihaj Mann, Bhavya, Liam Marrie--
--Assignment 3: Develop and Test a Coded Solution with Exception Handlers--

--server output on
SET SERVEROUTPUT ON;

DELCARE

--declare variables
LV_TRANSACTION_NO NEW_TRANSACTIONS.TRANSACTION_NO%TYPE;

DEBIT_TOTAL NUMBER := 0;

CREDIT_TOTAL NUMBER := 0;

TRANS_TYPE ACCOUNT_TYPE.DEFAULT_TRANS_TYPE%TYPE;

CHANGE_BY NUMBER;

V_ERROR_MSG VARCHAR2(200);

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
 --int vars for curr transactions
        LV_TRANSACTION_NO := REC_TRANSACTION.TRANSACTION_NO;
        DEBIT_TOTAL := 0;
        CREDIT_TOTAL := 0;
 --loop througb transactions details  for curr transaction
        FOR REC_DETAIL IN CUR_TRANSACTION_DETAILS(LV_TRANSACTION_NO) LOOP
            IF REC_DETAIL.TRANSACTION_TYPE = 'D' THEN
                DEBIT_TOTAL := DEBIT_TOTAL + REC_DETAIL.TRANSACTION_AMOUNT;
            ELSIF REC_DETAIL.TRANSACTION_TYPE = 'C' THEN
                CREDIT_TOTAL := CREDIT_TOTAL + REC_DETAILS.TRANSACTION_AMOUNT;
            ELSE
 --handle invalid transaction type
                V_ERROR_MSG := 'invalid transaction type: '
                               || REC_DETAIL.TRANSACTION_TYPE;
                INSERT INTO WKIS_ERROR_LOG (
                    TRANSACTION_NO,
                    ERROR_MSG
                ) VALUES (
                    LV_TRANSACTION_NO,
                    V_ERROR_MSG
                );
                DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
                CONTINUE;
            END IF;
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
            INSERT INTO TRANSACTION_DETAIL (
                ACCOUNT_NO,
                TRANSACTION_NO,
                TRANSACTION_TYPE,
                TRANSACTION_AMOUNT
            )VALUES(
                REC_DETAIL.ACCOUNT_NO,
                LV_TRANSACTION_NO,
                REC_DETAIL.TRANSACTION_TYPE,
                REC_DETAIL.TRANSACTION_AMOUNT
            );
        END LOOP;
 --check debits equal credits before committing
        IF DEBIT_TOTAL = CREDIT_TOTAL THEN
 --insert into transaction history
            INSERT INTO TRANSACTION_HISTORY(
                TRANSACTION_NO,
                TRANSACTION_DATE,
                DESCRIPTION
            )VALUES(
                LV_TRANSACTION_NO,
                REC_TRANSACTION.TRANSACTION_DATE,
                REC_TRANSACTION.DESCRIPTION
            );
 --commit transaction
            COMMIT;
 --delete processed transaction
            DELETE FROM NEW_TRANSACTIONS
            WHERE
                TRANSACTION_NO = LV_TRANSACTION_NO;
 --commit deletion
            COMMIT;
        ELSE
 --if debits != credits rollback and log the error
            ROLLBACK;
            V_ERROR_MSG := 'debit and credit totals do not match for transaction history: '
                           || TO_CHAR(LV_TRANSACTION_NO);
            INSERT INTO WKIS_ERROR_LOG (
                TRANSACTION_NO,
                ERROR_MSG
            ) VALUES (
                LV_TRANSACTION_NO,
                V_ERROR_MSG
            );
            DBMS_OUTPUT.PUT_LINE(V_ERROR_MSG);
        END IF;
    END LOOP;
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
    WHEN OTHERS THEN
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

set serveroutput off;
