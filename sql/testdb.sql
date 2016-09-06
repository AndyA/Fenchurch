-- MySQL dump 10.15  Distrib 10.0.19-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: test_adhocument
-- ------------------------------------------------------
-- Server version	10.0.19-MariaDB-1~wheezy

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
-- Table structure for table `test_conflicts`
--

DROP TABLE IF EXISTS `test_conflicts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_conflicts` (
  `uuid` varchar(36) NOT NULL,
  `parent` varchar(36) DEFAULT NULL,
  `serial` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `node` varchar(200) NOT NULL,
  `object` varchar(36) NOT NULL,
  `when` datetime NOT NULL,
  `sequence` int(10) unsigned NOT NULL,
  `rand` double NOT NULL,
  `kind` varchar(40) NOT NULL,
  `schema` text NOT NULL,
  `old_data` text,
  `new_data` text,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `test_conflicts_serial` (`serial`),
  KEY `test_conflicts_parent` (`parent`),
  KEY `test_conflicts_object` (`object`),
  KEY `test_conflicts_sequence` (`sequence`),
  KEY `test_conflicts_rand` (`rand`),
  KEY `test_conflicts_when` (`when`),
  KEY `test_conflicts_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_contributors`
--

DROP TABLE IF EXISTS `test_contributors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_contributors` (
  `_parent` varchar(36) NOT NULL COMMENT 'Parent object identifier',
  `index` int(11) NOT NULL COMMENT 'Sequential index within parent',
  `group` varchar(48) NOT NULL COMMENT 'Contributor group',
  `kind` varchar(48) NOT NULL COMMENT 'Contributor kind',
  `code` varchar(48) DEFAULT NULL COMMENT 'Contributor code',
  `type` varchar(256) DEFAULT NULL COMMENT 'Contributor type',
  `first_name` varchar(256) DEFAULT NULL COMMENT 'First name',
  `last_name` varchar(256) DEFAULT NULL COMMENT 'Last name',
  KEY `test_contributors__parent` (`_parent`),
  KEY `test_contributors_index` (`index`),
  KEY `test_contributors_group` (`group`),
  KEY `test_contributors_kind` (`kind`),
  KEY `test_contributors_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_item`
--

DROP TABLE IF EXISTS `test_item`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_item` (
  `_uuid` varchar(36) NOT NULL COMMENT 'Unique object identifier',
  `name` varchar(200) NOT NULL COMMENT 'Item name',
  PRIMARY KEY (`_uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_programmes_v2`
--

DROP TABLE IF EXISTS `test_programmes_v2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_programmes_v2` (
  `_uuid` varchar(36) NOT NULL COMMENT 'Unique object identifier',
  `_created` datetime NOT NULL COMMENT 'Creation timestamp',
  `_modified` datetime NOT NULL COMMENT 'Modification timestamp',
  `_key` varchar(48) NOT NULL COMMENT 'Unique kind-specific key',
  `_parent` varchar(36) DEFAULT NULL COMMENT 'Parent programme UUID',
  `_edit_id` int(10) DEFAULT NULL,
  `source` varchar(36) NOT NULL COMMENT 'Data source UUID',
  `service` varchar(36) DEFAULT NULL COMMENT 'Service UUID',
  `service_key` varchar(48) DEFAULT NULL COMMENT 'Service key',
  `issue` varchar(36) NOT NULL COMMENT 'Issue UUID',
  `issue_key` varchar(48) NOT NULL COMMENT 'Issue key',
  `listing` varchar(36) DEFAULT NULL COMMENT 'Listing UUID',
  `title` varchar(256) NOT NULL COMMENT 'Programme title',
  `episode_title` varchar(256) DEFAULT NULL COMMENT 'Episode title',
  `episode` int(11) DEFAULT NULL COMMENT 'Episode number',
  `synopsis` text COMMENT 'Synopsis text',
  `footnote` text COMMENT 'Footnote text',
  `text` text COMMENT 'Full text',
  `when` datetime NOT NULL COMMENT 'Schedule time',
  `duration` int(10) unsigned NOT NULL COMMENT 'Duration in seconds',
  `type` varchar(48) DEFAULT NULL COMMENT 'Programme type',
  `year` int(11) NOT NULL COMMENT 'Schedule year',
  `month` int(11) NOT NULL COMMENT 'Schedule month',
  `day` int(11) NOT NULL COMMENT 'Schedule day',
  `date` date DEFAULT NULL,
  `broadcast_date` date DEFAULT NULL,
  `page` int(11) DEFAULT NULL COMMENT 'First page number',
  PRIMARY KEY (`_uuid`),
  UNIQUE KEY `test_programmes_v2_source_key` (`source`,`_key`),
  KEY `test_programmes_v2__key` (`_key`),
  KEY `test_programmes_v2__parent` (`_parent`),
  KEY `test_programmes_v2_source` (`source`),
  KEY `test_programmes_v2_issue` (`issue`),
  KEY `test_programmes_v2_issue_key` (`issue_key`),
  KEY `test_programmes_v2_service` (`service`),
  KEY `test_programmes_v2_service_key` (`service_key`),
  KEY `test_programmes_v2_type` (`type`),
  KEY `test_programmes_v2_listing` (`listing`),
  KEY `test_programmes_v2_year` (`year`),
  KEY `test_programmes_v2_month` (`month`),
  KEY `test_programmes_v2_day` (`day`),
  KEY `date` (`date`),
  KEY `broadcast_date` (`broadcast_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_related`
--

DROP TABLE IF EXISTS `test_related`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_related` (
  `_uuid` varchar(36) NOT NULL COMMENT 'Unique object identifier',
  `_parent` varchar(36) NOT NULL COMMENT 'Parent object identifier',
  `index` int(11) NOT NULL COMMENT 'Sequential index within parent',
  `issue` varchar(36) NOT NULL COMMENT 'Issue UUID',
  `issue_key` varchar(48) NOT NULL COMMENT 'Issue key',
  `kind` varchar(48) NOT NULL COMMENT 'Kind of related content (e.g., "block")',
  `type` varchar(48) DEFAULT NULL COMMENT 'Type of related content (e.g., "text", "image")',
  `text` text COMMENT 'The textual content of the block, if any',
  `page` int(11) DEFAULT NULL COMMENT 'First page number of this related item',
  PRIMARY KEY (`_uuid`),
  KEY `test_related__parent` (`_parent`),
  KEY `test_related_index` (`index`),
  KEY `test_related_issue` (`issue`),
  KEY `test_related_issue_key` (`issue_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_tag`
--

DROP TABLE IF EXISTS `test_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_tag` (
  `_parent` varchar(36) DEFAULT NULL COMMENT 'Parent object identifier',
  `index` int(10) NOT NULL COMMENT 'Ordering',
  `name` varchar(200) NOT NULL COMMENT 'Tag name',
  KEY `test_tag__parent` (`_parent`),
  KEY `test_tag_index` (`index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_tree`
--

DROP TABLE IF EXISTS `test_tree`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_tree` (
  `_uuid` varchar(36) NOT NULL COMMENT 'Unique object identifier',
  `_parent` varchar(36) DEFAULT NULL COMMENT 'Parent object identifier',
  `name` varchar(200) NOT NULL COMMENT 'Node name',
  PRIMARY KEY (`_uuid`),
  KEY `test_tree__parent` (`_parent`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `test_versions`
--

DROP TABLE IF EXISTS `test_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_versions` (
  `uuid` varchar(36) NOT NULL,
  `parent` varchar(36) DEFAULT NULL,
  `serial` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `node` varchar(200) NOT NULL,
  `object` varchar(36) NOT NULL,
  `when` datetime NOT NULL,
  `sequence` int(10) unsigned NOT NULL,
  `rand` double NOT NULL,
  `kind` varchar(40) NOT NULL,
  `schema` text NOT NULL,
  `old_data` text,
  `new_data` text,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `test_versions_serial` (`serial`),
  KEY `test_versions_parent` (`parent`),
  KEY `test_versions_object` (`object`),
  KEY `test_versions_sequence` (`sequence`),
  KEY `test_versions_rand` (`rand`),
  KEY `test_versions_when` (`when`),
  KEY `test_versions_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2015-06-22 13:14:33
