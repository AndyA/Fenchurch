-- MySQL dump 10.15  Distrib 10.0.27-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: test_adhocument
-- ------------------------------------------------------
-- Server version	10.0.27-MariaDB-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `test_chain`
--

DROP TABLE IF EXISTS `test_chain`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_chain` (
  `uuid` varchar(36) NOT NULL,
  `parent` varchar(36) DEFAULT NULL,
  `serial` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `when` datetime NOT NULL,
  `name` varchar(200) NOT NULL,
  `rand` double NOT NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `test_chain_serial` (`serial`),
  KEY `test_chain_parent` (`parent`),
  KEY `test_chain_when` (`when`),
  KEY `test_chain_rand` (`rand`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_chain`
--

LOCK TABLES `test_chain` WRITE;
/*!40000 ALTER TABLE `test_chain` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_chain` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `test_chain_linear`
--

DROP TABLE IF EXISTS `test_chain_linear`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_chain_linear` (
  `uuid` varchar(36) NOT NULL,
  `parent` varchar(36) DEFAULT NULL,
  `serial` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `when` datetime NOT NULL,
  `name` varchar(200) NOT NULL,
  `rand` double NOT NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `test_chain_linear_serial` (`serial`),
  KEY `test_chain_linear_parent` (`parent`),
  KEY `test_chain_linear_when` (`when`),
  KEY `test_chain_linear_rand` (`rand`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_chain_linear`
--

LOCK TABLES `test_chain_linear` WRITE;
/*!40000 ALTER TABLE `test_chain_linear` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_chain_linear` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_conflicts`
--

LOCK TABLES `test_conflicts` WRITE;
/*!40000 ALTER TABLE `test_conflicts` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_conflicts` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_contributors`
--

LOCK TABLES `test_contributors` WRITE;
/*!40000 ALTER TABLE `test_contributors` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_contributors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `test_edit`
--

DROP TABLE IF EXISTS `test_edit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_edit` (
  `uuid` varchar(36) NOT NULL COMMENT 'Unique object identifier',
  `object` varchar(36) NOT NULL COMMENT 'Unique object identifier of target',
  `kind` varchar(64) NOT NULL COMMENT 'The kind of object changed',
  `old_data` text NOT NULL COMMENT 'JSON representation of previous data',
  `new_data` text NOT NULL COMMENT 'JSON representation of change',
  `state` enum('pending','accepted','rejected','review') NOT NULL DEFAULT 'pending' COMMENT 'Edit state',
  PRIMARY KEY (`uuid`),
  KEY `object` (`object`),
  KEY `kind` (`kind`),
  KEY `state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_edit`
--

LOCK TABLES `test_edit` WRITE;
/*!40000 ALTER TABLE `test_edit` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_edit` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_item`
--

LOCK TABLES `test_item` WRITE;
/*!40000 ALTER TABLE `test_item` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_item` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_programmes_v2`
--

LOCK TABLES `test_programmes_v2` WRITE;
/*!40000 ALTER TABLE `test_programmes_v2` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_programmes_v2` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `test_queue`
--

DROP TABLE IF EXISTS `test_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_queue` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID',
  `from` varchar(200) NOT NULL COMMENT 'Sending node name',
  `to` varchar(200) NOT NULL COMMENT 'Receiving node name',
  `when` datetime NOT NULL COMMENT 'Message timestamp',
  `message` text NOT NULL COMMENT 'Serialised message',
  PRIMARY KEY (`id`),
  KEY `from` (`from`),
  KEY `to` (`to`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_queue`
--

LOCK TABLES `test_queue` WRITE;
/*!40000 ALTER TABLE `test_queue` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_queue` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_related`
--

LOCK TABLES `test_related` WRITE;
/*!40000 ALTER TABLE `test_related` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_related` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `test_state`
--

DROP TABLE IF EXISTS `test_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `test_state` (
  `node` varchar(200) NOT NULL COMMENT 'Node name',
  `state` text NOT NULL COMMENT 'Serialised sync state',
  PRIMARY KEY (`node`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_state`
--

LOCK TABLES `test_state` WRITE;
/*!40000 ALTER TABLE `test_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_state` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_tag`
--

LOCK TABLES `test_tag` WRITE;
/*!40000 ALTER TABLE `test_tag` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_tag` ENABLE KEYS */;
UNLOCK TABLES;

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
-- Dumping data for table `test_tree`
--

LOCK TABLES `test_tree` WRITE;
/*!40000 ALTER TABLE `test_tree` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_tree` ENABLE KEYS */;
UNLOCK TABLES;

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

--
-- Dumping data for table `test_versions`
--

LOCK TABLES `test_versions` WRITE;
/*!40000 ALTER TABLE `test_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `test_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `utf8_test`
--

DROP TABLE IF EXISTS `utf8_test`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `utf8_test` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `data` text,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `utf8_test`
--

LOCK TABLES `utf8_test` WRITE;
/*!40000 ALTER TABLE `utf8_test` DISABLE KEYS */;
INSERT INTO `utf8_test` VALUES (1,'The Föundatiöns öf Music (non utf8, text field)','{\"text\":\"The FÃ¶undatiÃ¶ns Ã¶f Music (non utf8, text field)\"}'),(2,'The Föundatiöns öf Music (utf8, text field)','{\"text\":\"The FÃ¶undatiÃ¶ns Ã¶f Music (utf8, text field)\"}');
/*!40000 ALTER TABLE `utf8_test` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `utf8_test_chars`
--

DROP TABLE IF EXISTS `utf8_test_chars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `utf8_test_chars` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `data` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `utf8_test_chars`
--

LOCK TABLES `utf8_test_chars` WRITE;
/*!40000 ALTER TABLE `utf8_test_chars` DISABLE KEYS */;
/*!40000 ALTER TABLE `utf8_test_chars` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-10-07 13:37:37
