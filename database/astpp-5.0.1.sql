
-- --------------27-May-2021
DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_cdr_records` (IN `last_execution_time` DATETIME, IN `end_date` DATETIME)  BEGIN
INSERT INTO `cdrs_day_by_summary` (`account_id`, `reseller_id`, `type`, `country_id`, `billseconds`, `mcd`, `total_calls`, `debit`, `cost`, `total_answered_call`, `total_fail_call`, `unique_date`, `calldate`) (SELECT `accountid`, `reseller_id`, `type`, `country_id`, SUM(`billseconds`) AS `billseconds`, MAX(`billseconds`) AS `mcd`, COUNT(*) AS `total_calls`, SUM(`debit`) AS `debit`, SUM(`cost`) AS `cost`, COUNT(CASE WHEN `billseconds` > 0 THEN 1 END) AS `total_answered_call`, COUNT(CASE WHEN `billseconds`=0 THEN 1 END) AS `total_fail_call`, DATE_FORMAT(`callstart`, "%Y%m%d") AS `unique_date`, DATE_FORMAT(`callstart`, "%Y-%m-%d") AS `calldate` FROM `cdrs_staging` WHERE `end_stamp`>=`last_execution_time` AND `end_stamp` < `end_date` GROUP BY `accountid`, `country_id`, `reseller_id`, `unique_date`) ON DUPLICATE KEY UPDATE `billseconds`=(`billseconds` + VALUES(`billseconds`)), `debit`=(`debit` + VALUES(`debit`)), `cost`=(`cost` + VALUES(`cost`)), `total_answered_call`=(`total_answered_call` + VALUES(`total_answered_call`)), `total_fail_call`=(`total_fail_call` + VALUES(`total_fail_call`)), `calldate`=`calldate`, `mcd`=GREATEST(VALUES(`mcd`), `mcd`), `total_calls`=(`total_calls` + VALUES(`total_calls`));
UPDATE `reports_process_list` SET `last_execution_date`=`end_date` WHERE `name`='get_cdr_records';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `master_pro` ()  NO SQL
BEGIN
DECLARE done INT DEFAULT FALSE;
DECLARE rpl_id INT;
DECLARE rpl_name VARCHAR(50);
DECLARE rpl_date DATETIME;
DECLARE cur1 CURSOR 
FOR 
SELECT id,name,last_execution_date FROM reports_process_list;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
OPEN cur1;
read_loop: LOOP
  FETCH cur1 into rpl_id, rpl_name, rpl_date;
  IF done THEN
    LEAVE read_loop;
  END IF;
    SET @t1 =CONCAT("CALL ",rpl_name,"('",rpl_date,"','",UTC_TIMESTAMP(),"')");
  PREPARE stmt3 FROM @t1;
  EXECUTE stmt3;
  
END LOOP;

CLOSE cur1;
END$$

DELIMITER ;


DELIMITER $$
--
-- Events
--
CREATE DEFINER=`root`@`localhost` EVENT `remove_cdrs_records` ON SCHEDULE EVERY 1 HOUR STARTS '2019-05-24 19:03:57' ON COMPLETION NOT PRESERVE ENABLE DO DELETE FROM cdrs_staging where end_stamp <= (NOW()- INTERVAL 120 MINUTE)$$

CREATE DEFINER=`root`@`localhost` EVENT `staging_cdrs` ON SCHEDULE EVERY 1 MINUTE STARTS '2019-05-24 19:03:55' ON COMPLETION NOT PRESERVE ENABLE DO CALL master_pro()$$

DELIMITER ;

-- ------------------------------12-07-2021

DELETE FROM `system` WHERE `name`="paypal_status";

INSERT INTO `system` (`id`, `name`, `display_name`, `value`, `field_type`, `comment`, `timestamp`, `reseller_id`, `is_display`, `group_title`, `sub_group`, `field_rules`) VALUES (NULL, 'paypal_status', 'Paypal', '1', 'enable_disable_option', 'Set enable to add paypal as payment gateway option', '0000-00-00 00:00:00.000000', '0', '0', 'payment_methods', 'Paypal', '');

DELETE FROM `system` WHERE `name`="paypal_mode";

INSERT INTO `system` (`id`, `name`, `display_name`, `value`, `field_type`, `comment`, `timestamp`, `reseller_id`, `is_display`, `group_title`, `sub_group`, `field_rules`) VALUES (NULL, 'paypal_mode', 'Environment', '1', 'paypal_mode', 'Set paypal mode. Sandbox for testing', '0000-00-00 00:00:00.000000', '0', '0', 'payment_methods', 'Paypal', '');

-- -----------------------------13-07-2021

DELETE FROM `currency` WHERE `currency` in ('XAL','XCP','XAU','XPD','XPT','XAG');

UPDATE `currency` SET `currency` = 'MZN' WHERE `currency` = 'MZM';

INSERT INTO `default_templates` VALUES (NULL,'customer_refill_balance','You Received #AMOUNT# Amount to #SENDER_ACCOUNT_NUMBER# account','Balance transfer notification template','Dear #FIRST_NAME#, You Received #AMOUNT# Amount from your account to #SENDER_ACCOUNT_NUMBER#. Thanks, #COMPANY_NAME#','<p>You Received #AMOUNT# Amount from your account to #SENDER_ACCOUNT_NUMBER#</p>','<p>Dear #NAME#,</p>\r\n\r\n<p>You Received #AMOUNT# from your account to #SENDER_ACCOUNT_NUMBER#.</p>\r\n\r\n<p>If you have not raised a request then please contact us immediately.</p>\r\n\r\n<p>Thanks,<br />\r\n#COMPANY_NAME#</p>\r\n','2019-01-26 10:53:45',0,0,0,0,0);