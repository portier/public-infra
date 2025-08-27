# Portier project public infrastructure

This repository contains configuration and documentation for the public
infrastructure run by the Portier project.

 - DNS for portier.io is hosted by [Gandi], with the zone inside a 'Portier'
   organization managed by staff.

 - We host the public broker and demo at [Uberspace], including all
   inbound/outbound email.

 - We use the [Postmark DMARC] service to monitor performance of outbound mail.

 - For Google authentication, we maintain a Portier project on [Google Cloud]
   managed by staff. This project holds just the settings for the OAuth consent
   screen.

 - The main homepage is a redirect to GitHub pages, created from the
   [portier.github.io] repository.

[Gandi]: https://www.gandi.net/
[Uberspace]: https://uberspace.de/en/
[Postmark DMARC]: https://dmarc.postmarkapp.com/
[Google Cloud]: https://cloud.google.com/
[portier.github.io]: https://github.com/portier/portier.github.io/
