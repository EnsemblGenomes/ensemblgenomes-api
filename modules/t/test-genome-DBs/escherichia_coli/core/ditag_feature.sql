-- MySQL dump 10.14  Distrib 5.5.33a-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: test_escherichia_coli_core_21_74_1
-- ------------------------------------------------------
-- Server version	5.5.33a-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `ditag_feature`
--

DROP TABLE IF EXISTS `ditag_feature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ditag_feature` (
  `ditag_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ditag_id` int(10) unsigned NOT NULL DEFAULT '0',
  `ditag_pair_id` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_id` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_start` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_end` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_strand` tinyint(1) NOT NULL DEFAULT '0',
  `analysis_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `hit_start` int(10) unsigned NOT NULL DEFAULT '0',
  `hit_end` int(10) unsigned NOT NULL DEFAULT '0',
  `hit_strand` tinyint(1) NOT NULL DEFAULT '0',
  `cigar_line` tinytext NOT NULL,
  `ditag_side` enum('F','L','R') NOT NULL,
  PRIMARY KEY (`ditag_feature_id`),
  KEY `ditag_idx` (`ditag_id`),
  KEY `ditag_pair_idx` (`ditag_pair_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`,`seq_region_end`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-11-05 20:27:36
