-- Cdeopyright [1999-2014] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `compara_analysis`
--

DROP TABLE IF EXISTS `compara_analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compara_analysis` (
  `compara_analysis_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `division` varchar(64) NOT NULL,
  `method` varchar(50) NOT NULL,
  `set_name` varchar(64) DEFAULT NULL,
  `dbname` varchar(64) NOT NULL,
  PRIMARY KEY (`compara_analysis_id`)
) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

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
  `assembly_id` varchar(16) DEFAULT NULL,
  `assembly_name` varchar(200) NOT NULL,
  `assembly_level` varchar(50) NOT NULL,
  `base_count` int(10) unsigned NOT NULL,
  `genebuild` varchar(64) NOT NULL,
  `dbname` varchar(64) NOT NULL,
  `species_id` int(10) unsigned NOT NULL,
  `has_pan_compara` tinyint(3) unsigned DEFAULT '0',
  `has_variations` tinyint(3) unsigned DEFAULT '0',
  `has_peptide_compara` tinyint(3) unsigned DEFAULT '0',
  `has_genome_alignments` tinyint(3) unsigned DEFAULT '0',
  `has_other_alignments` tinyint(3) unsigned DEFAULT '0',
  PRIMARY KEY (`genome_id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `dbname_species_id` (`dbname`,`species_id`),
  UNIQUE KEY `assembly_id` (`assembly_id`)
) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_alias`
--

DROP TABLE IF EXISTS `genome_alias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_alias` (
  `genome_id` int(10) unsigned NOT NULL,
  `alias` varchar(255) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,
  UNIQUE KEY `id_alias` (`genome_id`,`alias`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_alignment`
--

DROP TABLE IF EXISTS `genome_alignment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_alignment` (
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `name` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type_key` (`genome_id`,`type`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_annotation`
--

DROP TABLE IF EXISTS `genome_annotation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_annotation` (
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type` (`genome_id`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_compara_analysis`
--

DROP TABLE IF EXISTS `genome_compara_analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_compara_analysis` (
  `genome_id` int(10) unsigned NOT NULL,
  `compara_analysis_id` int(10) unsigned NOT NULL,
  UNIQUE KEY `genome_compara_analysis_key` (`genome_id`,`compara_analysis_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_feature`
--

DROP TABLE IF EXISTS `genome_feature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_feature` (
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `analysis` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type_analysis` (`genome_id`,`type`,`analysis`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_publication`
--

DROP TABLE IF EXISTS `genome_publication`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_publication` (
  `genome_id` int(10) unsigned NOT NULL,
  `publication` varchar(64) DEFAULT NULL,
  UNIQUE KEY `id_publication` (`genome_id`,`publication`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_sequence`
--

DROP TABLE IF EXISTS `genome_sequence`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_sequence` (
  `genome_id` int(10) unsigned NOT NULL,
  `name` varchar(40) NOT NULL,
  `acc` varchar(24) DEFAULT NULL,
  UNIQUE KEY `id_alias` (`genome_id`,`name`,`acc`),
  KEY `acc` (`acc`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_variation`
--

DROP TABLE IF EXISTS `genome_variation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_variation` (
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `name` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type_key` (`genome_id`,`type`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-03-11 13:13:39
