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
-- Table structure for table `object_xref`
--

DROP TABLE IF EXISTS `object_xref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `object_xref` (
  `object_xref_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ensembl_id` int(10) unsigned NOT NULL,
  `ensembl_object_type` enum('RawContig','Transcript','Gene','Translation','Operon','OperonTranscript','Marker') NOT NULL,
  `xref_id` int(10) unsigned NOT NULL,
  `linkage_annotation` varchar(255) DEFAULT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`object_xref_id`),
  UNIQUE KEY `xref_idx` (`xref_id`,`ensembl_object_type`,`ensembl_id`,`analysis_id`),
  KEY `ensembl_idx` (`ensembl_object_type`,`ensembl_id`),
  KEY `analysis_idx` (`analysis_id`)
) ENGINE=MyISAM AUTO_INCREMENT=41062 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-11-05 20:27:36
