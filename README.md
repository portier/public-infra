# Portier project public infrastructure

This repository contains configuration and documentation for the public
infrastructure run by the Portier project.

 - DNS for portier.io is hosted by [Gandi], with the zone inside a 'Portier'
   organization managed by staff. We also use Gandi for web redirects and
   forwarding inbound email.

 - The main homepage is a Gandi redirect to GitHub pages, created from the
   [portier.github.io] repository.

 - We host all applications on [Hetzner Cloud](https://www.hetzner.com/cloud),
   using a VM inside a 'Portier' project managed by staff. The server
   configuration lives in `./server-config` in this repository. See the
   [README](./server-config/README.md) there for details.

 - We send outgoing mail using [Postmark], using an account managed by staff.
   All email tracking options are disabled. We also use the [Postmark DMARC]
   service to monitor performance.

 - For Google authentication, we maintain a Portier project on [Google Cloud]
   managed by staff. This project holds just the settings for the OAuth consent
   screen.

[Gandi]: https://www.gandi.net/
[portier.github.io]: https://github.com/portier/portier.github.io/
[Hetzner Cloud]: https://www.hetzner.com/cloud
[Postmark]: https://postmarkapp.com/
[Postmark DMARC]: https://dmarc.postmarkapp.com/
[Google Cloud]: https://cloud.google.com/
