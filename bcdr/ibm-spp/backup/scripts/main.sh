#!/bin/bash

# Perform pre backup steps for IBM Common Services
sh cs/prereq-cs-backup.sh

# Perform pre backup steps for Monitoring
sh monitoring/prereq-monitoring-backup.sh

# Perform pre backup steps for Managed Services
sh cam/prereq-cam-backup.sh

# Perform pre backup steps for IM
sh im/prereq-im-backup.sh