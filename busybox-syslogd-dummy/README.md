busybox-syslogd dummy
=====================

An empty package which replaces busybox-syslogd with rsyslog safely
with a low propability of bootloop because of the watchdog config
(keep in mind that this propability is still greater than zero).

It has to be build once and published with wb-configs (>= 1.84.3).
