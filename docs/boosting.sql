-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Versión del servidor:         11.4.3-MariaDB - mariadb.org binary distribution
-- SO del servidor:              Win64
-- HeidiSQL Versión:             12.6.0.6765
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- Volcando estructura para tabla osx.boosting_contracts
CREATE TABLE IF NOT EXISTS `boosting_contracts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `contractId` varchar(16) NOT NULL,
  `playerIdentifier` varchar(16) NOT NULL,
  `xpReward` int(11) NOT NULL DEFAULT 0,
  `creditReward` int(11) NOT NULL DEFAULT 0,
  `repReward` int(11) NOT NULL DEFAULT 0,
  `date` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `playerIdentifieru` (`playerIdentifier`),
  KEY `playerIdentifier` (`playerIdentifier`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- La exportación de datos fue deseleccionada.

-- Volcando estructura para tabla osx.boosting_players
CREATE TABLE IF NOT EXISTS `boosting_players` (
  `identifier` varchar(16) NOT NULL,
  `profile_name` varchar(32) DEFAULT 'Anónimo',
  `profile_picture` varchar(250) DEFAULT 'https://xxxx.xxxx.eu/images/interfaces/pfp.jpg',
  `xp` int(11) NOT NULL DEFAULT 0,
  `reputation` int(11) NOT NULL DEFAULT 0,
  `credits` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`),
  UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- La exportación de datos fue deseleccionada.

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
