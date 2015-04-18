-- MySQL dump 10.13  Distrib 5.1.61, for redhat-linux-gnu (x86_64)
--
-- Host: mysql-eg-devel-1.ebi.ac.uk    Database: test_ensemblgenomes_info_22
-- ------------------------------------------------------
-- Server version	5.5.36-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `genome`
--

DROP TABLE IF EXISTS `genome`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `species` varchar(128) NOT NULL,
  `name` varchar(128) NOT NULL,
  `strain` varchar(128) DEFAULT NULL,
  `serotype` varchar(128) DEFAULT NULL,
  `division` varchar(32) NOT NULL,
  `taxonomy_id` int(10) unsigned NOT NULL,
  `species_taxonomy_id` int(10) unsigned NOT NULL,
  `assembly_id` varchar(16) DEFAULT NULL,
  `assembly_name` varchar(200) NOT NULL,
  `assembly_level` varchar(50) NOT NULL,
  `base_count` bigint(20) unsigned NOT NULL,
  `genebuild` varchar(64) NOT NULL,
  `dbname` varchar(64) NOT NULL,
  `species_id` int(10) unsigned NOT NULL,
  `is_reference` tinyint(3) unsigned DEFAULT '0',
  `has_pan_compara` tinyint(3) unsigned DEFAULT '0',
  `has_variations` tinyint(3) unsigned DEFAULT '0',
  `has_peptide_compara` tinyint(3) unsigned DEFAULT '0',
  `has_genome_alignments` tinyint(3) unsigned DEFAULT '0',
  `has_synteny` tinyint(3) unsigned DEFAULT '0',
  `has_other_alignments` tinyint(3) unsigned DEFAULT '0',
  PRIMARY KEY (`genome_id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `dbname_species_id` (`dbname`,`species_id`),
  UNIQUE KEY `assembly_id` (`assembly_id`)
) ENGINE=MyISAM AUTO_INCREMENT=11182 DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-05-19 16:36:14
