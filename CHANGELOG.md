# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.1] - 2019-02-15
- Project began

## [0.0.2] - 2020-07-24

### Added
- Added cp4mcm-cleanup-utility.sh; it aids the customer in removing CP4MCM resources
- Added ma-prereq.sh; it aids the customer in installing Mutation Advisor prereas
- Added ma-prereq-offline.sh; it aids the customer in installing Mutation Advisor prereas for offline case.
- Added cp4mcm-ha-utility.sh; it aids the customer to enable HA for CP4MCM

[unreleased]: https://github.com/ibm/repo-template/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/ibm/repo-template/releases/tag/v0.0.1

## [0.0.3] - 2020-07-28

### Added
- Added the following three yaml files that are used for Unified Agent deployment:
  - `reloader.yaml`
  - `ua-deploy.yaml`
  - `ua-operator-deploy.yaml`

## [0.0.4] - 2020-09-30

### Added
- Added legacy search monitoring job deployment script
  - `scripts/monitor-mcm`

## [0.0.5] - 2020-10-20

### Added
- Added cloud native monitoring uninstall script
  - `scripts/cnmon/uninstall_cnmon.sh`

## [0.0.6] - 2020-10-22

### Added
- Added RHACM 2.1 issuer workaround script
  - `scripts/cp4mcm-rhacm21-cp-issuer-secret.sh`
  
## [0.0.6] - 2020-10-24
- Added uninstall.sh; it is a standalone utility to help the customer uninstall the Cloud Pak for MultiCloud Management; valid for use in CP4MCM 2.0
  - `scripts/uninstall.sh`
  
## [0.0.7] - 2020-10-27
- Removed default arguments to uninstall.sh
  - `scripts/uninstall.sh`
  
## [0.0.8] - 2020-11-30
- Updated cp4mcm-cleanup-utility.sh script to be more generic
  - `scripts/cp4mcm-cleanup-utility.sh`

## [0.0.9] - 2020-12-17
- Added grc-policy-updates.sh script to update GRC policy attributes when upgrading from mcm core 2.0 to RHACM 2.1
  - `scripts/grc-policy-updates.sh`
