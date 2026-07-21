.PHONY: calendar-assets calendar-library verify-calendar-assets

CALENDAR_LIBRARY := .build/calendar-library

calendar-library:
	mkdir -p $(CALENDAR_LIBRARY)
	R CMD INSTALL --library=$(CALENDAR_LIBRARY) .

calendar-assets: calendar-library
	R_LIBS=$(CALENDAR_LIBRARY) Rscript tools/build-vietnam-calendar-assets.R app-assets/vietnam-calendar

verify-calendar-assets: calendar-library
	R_LIBS=$(CALENDAR_LIBRARY) Rscript tools/verify-vietnam-calendar-assets.R app-assets/vietnam-calendar
