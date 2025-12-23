#Check how many claims number exists in df1 but not in claims_df
SELECT DISTINCT t.claimnumber
FROM df1_staging3_2 AS t
LEFT JOIN claims_staging5 AS s
	ON t.claimnumber = s.claimnumber
WHERE s.claimnumber IS NULL; #6415 claims exists in df1 but not in claims_df (while df1 has 13,709 distinct claims)

#Check how many claims in claims_staging5 but not in df1
SELECT DISTINCT claimnumber
FROM claims_staging5 
WHERE claimnumber NOT IN (SELECT DISTINCT claimnumber
							FROM df1_staging3_2); #0 claim


CREATE TABLE df1_diff_df2 AS
	SELECT t.*
	FROM df1_staging3 AS t
	LEFT JOIN claims_staging5 AS s
		ON t.claimnumber = s.claimnumber
		WHERE s.claimnumber IS NULL;

-- claimnumber, statusname (claim_status), accidentdate (claim_accident_date), requesterdate (claim_submitted_date), claim_opened_date (claim_opened_date), approveddate (ngay_duyet_bt) payment_date (paymentdate), processdays, cost_assetliquidation, cost_towing, 
-- cost_investigation, cost_copay_deductible (cost_copay_deductible), coverage (coverage), assignee_fullname (gdv_xu_ly), damage_type (damage_type) , loaixe (loaixe), hangxe (hangxe), customer_type (customer_type), 
-- agencycompensation (agencycompensation), damageestimation, claim_estimate_first (uoc_bt_ban_dau), total_claim_estimate (ubt_trans), compensation_total (stbt_truoc_thue)

#Create index on claimnumber for df1_diff_df2
CREATE INDEX idx_claimnumber_diff ON df1_diff_df2(claimnumber(25));
CREATE INDEX idx_claim_status_diff ON df1_diff_df2(claim_status_name(20));

#Change the status in df1_diff_df2 from approved to paid out if it is paid
WITH CTE_paidout AS (
	SELECT DISTINCT claimnumber
	FROM df1_diff_df2
	WHERE claim_status_name = 'paid out'
	)
UPDATE df1_diff_df2
SET claim_status = 'paid out'
WHERE claim_status = 'approved' AND claimnumber IN (SELECT claimnumber FROM CTE_paidout);

#Translate damage_type column values
SELECT DISTINCT damage_type FROM df1_diff_df2;
-- 'Unknown'  
-- 'Tổn thất về người' -> Personal Injury Loss
-- 'Tổn thất bộ phận/toàn bộ' -> Partial/Total Loss
-- 'Tài sản bên thứ 3 về xe' -> Third-Party Vehicle Property
-- 'Tài sản bên thứ 3 khác' -> Other Third-Party Property
-- 'Mất cắp bộ phận' -> Theft

UPDATE df1_diff_df2
SET damage_type = CASE 
						WHEN damage_type = 'Tổn thất về người' THEN 'Personal Injury Loss'
						WHEN damage_type = 'Tổn thất bộ phận/toàn bộ' THEN 'Partial/Total Loss'
                        WHEN damage_type = 'Tài sản bên thứ 3 về xe' THEN 'Third-Party Vehicle Property'
                        WHEN damage_type = 'Tài sản bên thứ 3 khác' THEN 'Other Third-Party Property'
                        WHEN damage_type = 'Mất cắp bộ phận' THEN 'Theft'
                        ELSE THEN 'Unknown'
					END;

#Check for Null/Empty values in df1_diff_df2
SELECT claimnumber, agencycompensation
FROM df1_diff_df2
WHERE agencycompensation = '' OR agencycompensation = '-' OR agencycompensation IS NULL;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE stbt_truoc_thue = '' AND claim_status = 'paid out' AND claim_status_name = 'paid out'; #0

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE ubt_trans = '' ; #0

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE uoc_bt_ban_dau = '' ;

#Fill 0 into empty rows of ubt_trans, uoc_bt_ban_dau, stbt_truoc_thue
UPDATE df1_diff_df2
SET  ubt_trans = '0'
WHERE ubt_trans = '';

UPDATE df1_diff_df2
SET  uoc_bt_ban_dau = '0'
WHERE uoc_bt_ban_dau = '';

UPDATE df1_diff_df2
SET  stbt_truoc_thue = '0'
WHERE stbt_truoc_thue = '';

#Convert datatype from Text to Numeric
ALTER TABLE df1_diff_df2
MODIFY uoc_bt_ban_dau DECIMAL(15,2);

ALTER TABLE df1_diff_df2
MODIFY ubt_trans DECIMAL(15,2);

ALTER TABLE df1_diff_df2
MODIFY stbt_truoc_thue DECIMAL(15,2);


#**
SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022200210C005149' #paid out
ORDER BY updateddate;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022200303C001743' #in process
ORDER BY updateddate;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022200606C013431' #submitted
ORDER BY updateddate;


SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022200806C008278' #in process
ORDER BY updateddate;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022200806C012087' #approved
ORDER BY updateddate;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022201107C008839' #cancelled (get ubt_trans & uoc_bt_ban_dau of in-process row)
ORDER BY updateddate;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claimnumber = 'A022200505C011501' #paid out
ORDER BY updateddate;

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claim_status = 'denied' 
ORDER BY claimnumber, updateddate; #denied

SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1_diff_df2
WHERE claim_status = 'approved' 
ORDER BY claimnumber, updateddate; #approved

-- ## SUBMITTED ##

-- #for submitted, get the last row
-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 		RANK() OVER (PARTITION BY claimnumber, claim_status ORDER BY stbt_truoc_thue DESC, ubt_trans DESC, uoc_bt_ban_dau DESC, updateddate DESC) as row_num
-- FROM df1_diff_df2
-- WHERE claim_status = 'submitted';

-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claim_status = 'in process'
-- ORDER BY claimnumber, updateddate;

#check if there's any submitted claim that has ubt_trans or uoc_bt_ban_dau empty
-- WITH submitted_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			RANK() OVER (PARTITION BY claimnumber, claim_status ORDER BY stbt_truoc_thue DESC, ubt_trans DESC, uoc_bt_ban_dau DESC, updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'submitted')
-- SELECT * 
-- FROM submitted_emptyCTE
-- WHERE row_num = 1 AND (ubt_trans = 0 OR uoc_bt_ban_dau = 0); #0

## IN PROCESS ##

#Check for how many claim that have > 1 'in process' row and stbt_truoc_thue diff & one of them != 0
-- SELECT claimnumber, COUNT(DISTINCT(stbt_truoc_thue))
-- FROM df1_diff_df2
-- WHERE claim_status = 'in process' AND claim_status_name = 'in process' AND stbt_truoc_thue != 0
-- GROUP BY claimnumber
-- HAVING COUNT(DISTINCT stbt_truoc_thue) > 1; #79

-- -- 'A022200505C012958','2'
-- -- 'A022200510C011918','2'
-- -- 'A022200606C010117','2'
-- -- 'A022200607C012782','2'

-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claimnumber = 'A022200510C011918'
-- ORDER BY claimnumber, updateddate;

-- #For 'in process', get the latest row of claim_status_name
-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 		ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- FROM df1_diff_df2
-- WHERE claim_status = 'in process' AND claim_status_name = 'in process'; #2211

-- #check if there's any 'in process' claim that has ubt_trans or uoc_bt_ban_dau empty
-- WITH submitted_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'in process')
-- SELECT * 
-- FROM submitted_emptyCTE
-- WHERE row_num = 1 AND (ubt_trans = 0 OR uoc_bt_ban_dau = 0); #0

-- ## CANCELLED ##
-- SELECT claimnumber, COUNT(DISTINCT(ubt_trans))
-- FROM df1_diff_df2
-- WHERE claim_status = 'cancelled' AND claim_status_name = 'in process'
-- GROUP BY claimnumber
-- HAVING COUNT(DISTINCT ubt_trans) > 1; #3

-- -- 'A022200808C003844','3'
-- -- 'A022204611C009838','2'
-- -- 'A032202906C004174','2'

-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claimnumber = 'A032202906C004174'
-- ORDER BY updateddate;

-- #For 'cancelled', get ubt_trans & uoc_bt_ban_dau of in-process row
-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 		ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- FROM df1_diff_df2
-- WHERE claim_status = 'cancelled' AND claim_status_name = 'in process'; #22

-- #For 'cancelled', get ubt_trans & uoc_bt_ban_dau of row_num = 2. Keep claimw w/o row_num > 1
-- WITH cancelled_CTE AS (
-- 			SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 					ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 			FROM df1_diff_df2
-- 			WHERE claim_status = 'cancelled')
-- SELECT * 
-- FROM cancelled_CTE
-- WHERE row_num = 1 AND claimnumber NOT IN (SELECT claimnumber FROM cancelled_CTE WHERE row_num = 2)
-- ;

-- #check if there's any 'cancelled' claim that has ubt_trans or uoc_bt_ban_dau empty
-- WITH submitted_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'cancelled' AND claim_status_name = 'in process')
-- SELECT * 
-- FROM submitted_emptyCTE
-- WHERE row_num = 1 AND (ubt_trans = 0 OR uoc_bt_ban_dau = 0); #0

-- ##APPROVE##
-- -- 'approved' row always has ubt_trans = 0 -> we need to get ubt_trans value from the latest 'in process' row

-- SELECT claimnumber
-- FROM df1_diff_df2
-- WHERE claim_status = 'approved' AND claim_status_name = 'approved'
-- GROUP BY claimnumber
-- HAVING COUNT(DISTINCT stbt_truoc_thue) > 1; #128

-- -- 'A022200303C010889'
-- -- 'A022200305C009826'
-- -- 'A022200305C012549'
-- -- 'A022200306C011869'
-- -- 'A022200308C008540'

-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claimnumber = 'A022200303C010889'
-- ORDER BY claimnumber, updateddate;

-- #find claim_status_name = 'approved' with ubt_trans != 0
-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claim_status_name = 'approved' AND ubt_trans != 0
-- ORDER BY claimnumber, updateddate; #0

-- #For 'approved', if all rows in stbt_truoc_thue are diff, then take the sum(stbt_truoc_thue)
-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 		ROW_NUMBER() OVER (PARTITION BY claimnumber, stbt_truoc_thue ORDER BY updateddate DESC) as row_num
-- FROM df1_diff_df2
-- WHERE claim_status = 'approved' AND claim_status_name = 'approved';

-- #Check if uoc_bt_truoc_thue, ubt_trans is empty in those rows
-- WITH approved_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			ROW_NUMBER() OVER (PARTITION BY claimnumber, stbt_truoc_thue ORDER BY updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'approved' AND claim_status_name = 'approved')
-- SELECT *
-- FROM approved_emptyCTE
-- WHERE row_num = 1 AND (stbt_truoc_thue = 0 OR ubt_trans = 0 OR uoc_bt_ban_dau = 0); #'A022204607C009268' #1135 claims with ubt_trans = 0

-- #Check if those 1135 claims have ubt_trans = 0
-- WITH approved_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'approved' AND claim_status_name = 'approved')
-- SELECT *
-- FROM approved_emptyCTE
-- WHERE row_num = 1 AND stbt_truoc_thue = 0; #'A022204607C009268'

-- #Check if those 1135 claims have ubt_trans = 0
-- WITH approved_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'approved' AND claim_status_name = 'approved')
-- SELECT *
-- FROM approved_emptyCTE
-- WHERE row_num = 1 AND ubt_trans = 0; #1000 rows w ubt_trans = 0

-- #Check if those claims have uoc_bt_ban_dau = 0
-- WITH approved_emptyCTE AS
-- 	(SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate,
-- 			ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 	FROM df1_diff_df2
-- 	WHERE claim_status = 'approved' AND claim_status_name = 'approved')
-- SELECT *
-- FROM approved_emptyCTE
-- WHERE row_num = 1 AND uoc_bt_ban_dau = 0; #0

-- #Check if those 1135 claims have ubt_trans = 0 in claim_status_name = 'in process' or 'submitted'

-- ## DENIED ##

-- SELECT claimnumber, COUNT(DISTINCT(ubt_trans))
-- FROM df1_diff_df2
-- WHERE claim_status = 'denied' AND claim_status_name = 'in process' AND ubt_trans != 0
-- GROUP BY claimnumber
-- HAVING COUNT(DISTINCT ubt_trans) > 1; #1

-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claimnumber = 'A022204504C008717'
-- ORDER BY updateddate; 

-- #Find the row in which claim_status = 'denied' and ubt_trans = 0
-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claim_status = 'denied' AND claim_status_name = 'denied' AND ubt_trans = 0; #0


-- ## PAID OUT ##

-- #claims with > 1 'paid out' rows and the stbt_truoc_thue in each row are diff and != 0
-- SELECT claimnumber, COUNT(DISTINCT(stbt_truoc_thue))
-- FROM df1_diff_df2
-- WHERE claim_status = 'paid out' AND claim_status_name = 'paid out' AND stbt_truoc_thue != 0
-- GROUP BY claimnumber
-- HAVING COUNT(DISTINCT stbt_truoc_thue) > 1; #288
-- -- 'A022200205C010121','2'
-- -- 'A022200206C006231','2'
-- -- 'A022200206C010128','2'
-- -- 'A022200210C005149','3'

-- SELECT claimnumber, claim_status, claim_status_name, stbt_truoc_thue, ubt_trans, uoc_bt_ban_dau, updateddate
-- FROM df1_diff_df2
-- WHERE claimnumber = 'A022200210C005149'
-- ORDER BY updateddate;


#translate column name, values
UPDATE df1_diff_df2
SET customer_type = CASE 
					WHEN customer_type = 'Cá nhân' THEN 'personal'
                    WHEN customer_type = 'Tổ chức' THEN 'business'
                    END;
					
-- #get the latest rows (newest updateddate)
-- CREATE TABLE diff_staging1 AS
-- SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) AS row_num
-- FROM df1_diff_df2;

-- DELETE FROM diff_staging1
-- WHERE row_num > 1;

-- SELECT * FROM diff_staging1;

#Transalte column name
-- statusname (claim_status), accidentdate (claim_accident_date), requesterdate (claim_submitted_date), claim_opened_date (claim_opened_date), approveddate (claim_approved_date), payment_date (paymentdate), processdays, cost_assetliquidation, cost_towing, 
-- cost_investigation, cost_copay_deductible (cost_copay_deductible), coverage (coverage), assignee_fullname (gdv_xu_ly), damage_type (damage_type) , loaixe (loaixe), hangxe (hangxe), customer_type (customer_type), 
-- agencycompensation (agencycompensation), damageestimation, claim_estimate_first (uoc_bt_ban_dau), total_claim_estimate (ubt_trans), compensation_total (stbt_truoc_thue)

-- claim_status (claim_status), claim_accident_date (claim_accident_date), claim_submitted_date (claim_submitted_date), claim_opened_date (claim_opened_date), claim_approved_date (claim_approved_date) payment_date (payment_date), processdays, cost_assetliquidation, cost_towing, 
-- cost_investigation, cost_copay_deductible (cost_copay_deductible), coverage (coverage), assignee_fullname (assignee_fullname), damage_type (damage_type) , vehicle_type (vehicle_type), vehicle_make (vehicle_make), customer_type (customer_type), 
-- agencycompensation (agencycompensation), damageestimation, claim_estimate_first (claim_estimate_first), total_claim_estimate (total_claim_estimate), compensation_total (compensation_total)


SELECT DISTINCT claimnumber FROM df1_diff_df2_staging1; #6415
SELECT DISTINCT claimnumber FROM claims_staging6; #7294
-- -> 13,709 claims

#Get the date only (exclude the time) for date columns
ALTER TABLE df1_diff_df2_staging1
MODIFY claim_accident_date DATE;

ALTER TABLE df1_diff_df2_staging1
MODIFY claim_submitted_date DATE;

ALTER TABLE df1_diff_df2_staging1
MODIFY claim_opened_date DATE;

ALTER TABLE df1_diff_df2_staging1
MODIFY paymentdate DATE;
 
-- Get the payment date the same as claim_approved_date
UPDATE df1_diff_df2_staging1
SET paymentdate = DATE(STR_TO_DATE(paymentdate, '%d/%m/%Y'))
WHERE paymentdate != '';

#Fill in empty values for paymentdate in df1_diff_df2_staging1
SELECT claimnumber, claim_status, claim_accident_date, claim_submitted_date, claim_opened_date, claim_approved_date, paymentdate
FROM df1_diff_df2_staging1 
WHERE claim_status = 'paid out' AND (paymentdate = '' OR paymentdate = '-' OR paymentdate IS NULL); #13 rows, empty paymentdate

UPDATE df1_diff_df2_staging1
SET paymentdate = claim_approved_date
WHERE claim_status = 'paid out' AND paymentdate = '';

UPDATE df1_diff_df2_staging1
SET paymentdate = NULL
WHERE paymentdate = ''; 


#Translate column names & convert data type
ALTER TABLE df1_diff_df2_staging1
CHANGE paymentdate payment_date DATE;

ALTER TABLE df1_diff_df2_staging1
CHANGE gdv_xu_ly assignee_fullname TEXT;

ALTER TABLE df1_diff_df2_staging1
CHANGE loaixe vehicle_type TEXT;

ALTER TABLE df1_diff_df2_staging1
CHANGE hangxe vehicle_make TEXT;

#Create new table to drop unnecessary columns and translate column names to match with claims_staging
CREATE TABLE df1_diff_df2_staging2 AS
SELECT claimnumber, claim_status, claim_accident_date, claim_submitted_date, claim_opened_date, claim_approved_date,
		payment_date, cost_copay_deductible, coverage, assignee_fullname, damage_type, vehicle_type, vehicle_make, customer_type,
        agencycompensation, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_diff_df2_staging1;

#convert numeric data type columns to match claims_staging
SELECT cost_copay_deductible, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue
FROM df1_diff_df2_staging2;

ALTER TABLE df1_diff_df2_staging2
CHANGE uoc_bt_ban_dau claim_estimate_first DECIMAL(15,2);

ALTER TABLE df1_diff_df2_staging2
CHANGE ubt_trans total_claim_estimate DECIMAL(15,2);

ALTER TABLE df1_diff_df2_staging2
CHANGE stbt_truoc_thue compensation_total DECIMAL(15,2);

-- Check null values at numerical value columns
SELECT *
FROM df1_diff_df2_staging2
WHERE claim_estimate_first IS NULL OR total_claim_estimate IS NULL OR compensation_total IS NULL;

-- Fill in null value
UPDATE df1_diff_df2_staging2
SET total_claim_estimate = 0
WHERE claimnumber = 'A022201105C000664';


#Add columns processdays & Calculate processdays
ALTER TABLE df1_diff_df2_staging2
ADD COLUMN processdays INT;


-- Check for payment_date (they all wrong)
SELECT *
FROM df1_diff_df2_staging2
WHERE claim_status = 'paid out';

ALTER TABLE df1_diff_df2_staging2
MODIFY COLUMN updateddate DATE; 

-- Update correct payment_date by replacing it with updateddate at row = 'paid out'
UPDATE df1_diff_df2_staging2
SET payment_date = updateddate
WHERE claim_status = 'paid out';

#paid out = payment_date - claim_submitted_date
UPDATE df1_diff_df2_staging2
SET processdays = DATEDIFF(payment_date, claim_submitted_date)
WHERE claim_status = 'paid out';

#submitted = updateddate - claim_submitted_date
UPDATE df1_diff_df2_staging2
SET processdays = DATEDIFF(updateddate, claim_submitted_date)
WHERE claim_status = 'submitted' OR claim_status = 'cancelled' OR claim_status = 'in process' OR claim_status = 'denied';

#approved = claim_approved_date - claim_submitted_date
UPDATE df1_diff_df2_staging2
SET processdays = DATEDIFF(claim_approved_date, claim_submitted_date)
WHERE claim_status = 'approved';

SELECT claimnumber, claim_status, claim_submitted_date, processdays, claim_status
FROM df1_diff_df2_staging2;

-- Update claim_status' from varchar(20) to Text
ALTER TABLE df1_diff_df2_staging2
MODIFY COLUMN claim_status TEXT;

#check null for number columns
-- 'claim_estimate_first', 'decimal(15,2)', 'YES', '', NULL, ''
-- 'total_claim_estimate', 'decimal(15,2)', 'YES', '', NULL, ''
-- 'compensation_total', 'varchar(17)', 'YES', '', NULL, ''
-- 'cost_copay_deductible'

SELECT *
FROM df1_diff_df2_staging2
WHERE claim_estimate_first IS NULL OR total_claim_estimate IS NULL OR compensation_total IS NULL OR cost_copay_deductible IS NULL;


-- For paid out claims, get the correct payment_date by finding the updateddate of claim_status_name = 'Đã chi trả bồi thường' from df1
-- CREATE TEMPORARY TABLE paidout_date AS (
-- 	SELECT claimnumber, claim_status_name, updateddate,
-- 		ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC) as row_num
-- 	FROM df1_staging
--     WHERE claim_status_name = 'Đã chi trả bồi thường');
--     
-- SELECT DISTINCT claimnumber
-- FROM paidout_date
-- WHERE row_num > 1; #1443

-- SELECT *
-- FROM paidout_date;

-- ALTER TABLE paidout_date
-- MODIFY COLUMN updateddate DATE;

-- #get the row_num = 1 (newest updateddate only)
-- DELETE FROM paidout_date
-- WHERE row_num > 1;

-- Join paidout_date & df1_diff_df2_staging2 to update the payment_date
-- UPDATE df1_diff_df2_staging2 AS t
-- JOIN paidout_date AS s
-- ON t.claimnumber = s.claimnumber
-- SET t.paymnet_date = s.updateddate; 

-- SELECT *
-- FROM df1_diff_df2_staging2
-- WHERE claim_status = 'paid out';
-- 'A022102906C000112','paid out','2021-12-26','2021-12-26','2021-12-26','2022-09-28','2021-12-02','0','Personal injury coverage','Vòong Nguyễn Thiên Vương','Personal Injury Loss','Xe đầu kéo','INTERNATIONAL','business','Bảo Long Bình Định','20000000.00','28400000.00','28400000.00','2022-09-28 00:00:00'
-- 'A022103005C000138','paid out','2021-12-28','2021-12-28','2021-12-28','2022-06-29','2021-12-16','1000000','Collision coverage','Đào Viết Hòa','Partial/Total Loss','Xe không kinh doanh đến 08 chỗ','TOYOTA','personal','Bảo Long Phú Thọ','5000000.00','1805000.00','1640909.00','2022-09-21 00:00:00'
-- 'A022103808C000123','paid out','2021-12-26','2021-12-26','2021-12-27','2022-04-07','2022-01-10','1000000','Collision coverage','Bế Văn Tuyền','Partial/Total Loss','Xe không kinh doanh đến 08 chỗ','MAZDA','personal','Bảo Long Lâm Đồng','6000000.00','5545000.00','5040909.00','2022-04-20 00:00:00'

-- SELECT claimnumber, claim_status, claim_submitted_date, claim_opened_date, payment_date, updateddate
-- FROM df1_diff_df2_staging2
-- WHERE claimnumber = 'A022102906C000112' OR claimnumber = 'A022103005C000138' OR claimnumber = 'A022103808C000123';
-- 'A022102906C000112', 'paid out', '2021-12-26', '2021-12-26', '2021-12-02', '2022-09-28 00:00:00'
-- 'A022103005C000138', 'paid out', '2021-12-28', '2021-12-28', '2021-12-16', '2022-09-21 00:00:00'
-- 'A022103808C000123', 'paid out', '2021-12-26', '2021-12-27', '2022-01-10', '2022-04-20 00:00:00'


-- SELECT *
-- FROM paidout_date
-- WHERE claimnumber = 'A022102906C000112' OR claimnumber = 'A022103005C000138' OR claimnumber = 'A022103808C000123';
-- 'A022102906C000112', 'Đã chi trả bồi thường', '2022-09-28', '1'
-- 'A022103005C000138', 'Đã chi trả bồi thường', '2022-09-21', '1'
-- 'A022103808C000123', 'Đã chi trả bồi thường', '2022-09-18', '1'

#Create new table to drop unnecessary columns and translate column names to match with claims_staging
CREATE TABLE df1_diff_df2_staging3 AS
SELECT claimnumber, policycode, claim_status, claim_accident_date, claim_submitted_date, claim_opened_date, claim_approved_date,
		payment_date, cost_copay_deductible, coverage, assignee_fullname, damage_type, vehicle_type, vehicle_make, customer_type,
        agencycompensation, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_diff_df2_staging1;

#convert numeric data type columns to match claims_staging

ALTER TABLE df1_diff_df2_staging3
CHANGE uoc_bt_ban_dau claim_estimate_first DECIMAL(15,2);

ALTER TABLE df1_diff_df2_staging3
CHANGE ubt_trans total_claim_estimate DECIMAL(15,2);

ALTER TABLE df1_diff_df2_staging3
CHANGE stbt_truoc_thue compensation_total DECIMAL(15,2);

-- Fill in null value
UPDATE df1_diff_df2_staging3
SET total_claim_estimate = 0
WHERE claimnumber = 'A022201105C000664';


#Add columns processdays & Calculate processdays
ALTER TABLE df1_diff_df2_staging3
ADD COLUMN processdays INT;


-- Check for payment_date (they all wrong)

ALTER TABLE df1_diff_df2_staging3
MODIFY COLUMN updateddate DATE; 

-- Update correct payment_date by replacing it with updateddate at row = 'paid out'
UPDATE df1_diff_df2_staging3
SET payment_date = updateddate
WHERE claim_status = 'paid out';

#paid out = payment_date - claim_submitted_date
UPDATE df1_diff_df2_staging3
SET processdays = DATEDIFF(payment_date, claim_submitted_date)
WHERE claim_status = 'paid out';

#submitted = updateddate - claim_submitted_date
UPDATE df1_diff_df2_staging3
SET processdays = DATEDIFF(updateddate, claim_submitted_date)
WHERE claim_status = 'submitted' OR claim_status = 'cancelled' OR claim_status = 'in process' OR claim_status = 'denied';

#approved = claim_approved_date - claim_submitted_date
UPDATE df1_diff_df2_staging3
SET processdays = DATEDIFF(claim_approved_date, claim_submitted_date)
WHERE claim_status = 'approved';


-- Update claim_status' from varchar(20) to Text
ALTER TABLE df1_diff_df2_staging3
MODIFY COLUMN claim_status TEXT;
