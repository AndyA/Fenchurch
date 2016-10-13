-- MySQL dump 10.15  Distrib 10.0.27-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: fenchurch_wiki
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
-- Table structure for table `fenchurch_known`
--

DROP TABLE IF EXISTS `fenchurch_known`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fenchurch_known` (
  `uuid` varchar(36) NOT NULL,
  PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fenchurch_known`
--

LOCK TABLES `fenchurch_known` WRITE;
/*!40000 ALTER TABLE `fenchurch_known` DISABLE KEYS */;
/*!40000 ALTER TABLE `fenchurch_known` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fenchurch_pending`
--

DROP TABLE IF EXISTS `fenchurch_pending`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fenchurch_pending` (
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
  UNIQUE KEY `fenchurch_versions_serial` (`serial`),
  KEY `fenchurch_versions_parent` (`parent`),
  KEY `fenchurch_versions_object` (`object`),
  KEY `fenchurch_versions_sequence` (`sequence`),
  KEY `fenchurch_versions_rand` (`rand`),
  KEY `fenchurch_versions_when` (`when`),
  KEY `fenchurch_versions_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fenchurch_pending`
--

LOCK TABLES `fenchurch_pending` WRITE;
/*!40000 ALTER TABLE `fenchurch_pending` DISABLE KEYS */;
/*!40000 ALTER TABLE `fenchurch_pending` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fenchurch_queue`
--

DROP TABLE IF EXISTS `fenchurch_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fenchurch_queue` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID',
  `role` varchar(200) NOT NULL COMMENT 'Queue role',
  `from` varchar(200) NOT NULL COMMENT 'Sending node name',
  `to` varchar(200) NOT NULL COMMENT 'Receiving node name',
  `when` datetime NOT NULL COMMENT 'Message timestamp',
  `message` text NOT NULL COMMENT 'Serialised message',
  PRIMARY KEY (`id`),
  KEY `role` (`role`),
  KEY `from` (`from`),
  KEY `to` (`to`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fenchurch_queue`
--

LOCK TABLES `fenchurch_queue` WRITE;
/*!40000 ALTER TABLE `fenchurch_queue` DISABLE KEYS */;
/*!40000 ALTER TABLE `fenchurch_queue` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fenchurch_state`
--

DROP TABLE IF EXISTS `fenchurch_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fenchurch_state` (
  `local_node` varchar(200) NOT NULL COMMENT 'Local node name',
  `remote_node` varchar(200) NOT NULL COMMENT 'Remote node name',
  `updated` datetime NOT NULL,
  `state` text NOT NULL COMMENT 'Serialised sync state',
  PRIMARY KEY (`local_node`,`remote_node`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fenchurch_state`
--

LOCK TABLES `fenchurch_state` WRITE;
/*!40000 ALTER TABLE `fenchurch_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `fenchurch_state` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fenchurch_versions`
--

DROP TABLE IF EXISTS `fenchurch_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fenchurch_versions` (
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
  UNIQUE KEY `fenchurch_versions_serial` (`serial`),
  KEY `fenchurch_versions_parent` (`parent`),
  KEY `fenchurch_versions_object` (`object`),
  KEY `fenchurch_versions_sequence` (`sequence`),
  KEY `fenchurch_versions_rand` (`rand`),
  KEY `fenchurch_versions_when` (`when`),
  KEY `fenchurch_versions_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fenchurch_versions`
--

LOCK TABLES `fenchurch_versions` WRITE;
/*!40000 ALTER TABLE `fenchurch_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `fenchurch_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wiki_page`
--

DROP TABLE IF EXISTS `wiki_page`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wiki_page` (
  `uuid` varchar(36) NOT NULL,
  `slug` varchar(80) DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `text` text,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wiki_page`
--

LOCK TABLES `wiki_page` WRITE;
/*!40000 ALTER TABLE `wiki_page` DISABLE KEYS */;
/*!40000 ALTER TABLE `wiki_page` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-10-10 17:29:54
