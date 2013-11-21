INSTALL_DIR=/usr/local/bin/
SHED=shed
install :
	ln -s $(CURDIR)/shed.sh $(INSTALL_DIR)$(SHED)
	chmod +x $(INSTALL_DIR)$(SHED)
clean :
	rm $(INSTALL_DIR)$(SHED)

	
