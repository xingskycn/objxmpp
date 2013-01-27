/*
 * Copyright (c) 2013, Florian Zeitz <florob@babelmonkeys.de>
 *
 * https://webkeks.org/git/?p=objxmpp.git
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice is present in all copies.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "XMPPContact.h"
#import "XMPPContactManager.h"
#import "XMPPJID.h"
#import "XMPPMulticastDelegate.h"
#import "XMPPPresence.h"
#import "XMPPRosterItem.h"

@implementation XMPPContactManager
- initWithConnection: (XMPPConnection*)connection_
	      roster: (XMPPRoster*)roster_
{
	self = [super init];

	@try {
		connection = connection_;
		[connection addDelegate: self];
		roster = roster_;
		[roster addDelegate: self];
		contacts = [[OFMutableDictionary alloc] init];
		delegates = [[XMPPMulticastDelegate alloc] init];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[connection removeDelegate: self];
	[roster removeDelegate: self];
	[delegates release];
	[contacts release];

	[super dealloc];
}

- (void)addDelegate: (id <XMPPConnectionDelegate>)delegate
{
	[delegates addDelegate: delegate];
}

- (void)removeDelegate: (id <XMPPConnectionDelegate>)delegate
{
	[delegates removeDelegate: delegate];
}

- (OFDictionary*)contacts
{
	OF_GETTER(contacts, YES);
}

- (void)rosterWasReceived: (XMPPRoster*)roster_
{
	OFEnumerator *contactEnumerator;
	XMPPContact *contact;
	OFDictionary *rosterItems;
	OFEnumerator *rosterItemEnumerator;
	OFString *bareJID;

	contactEnumerator = [contacts objectEnumerator];
	while ((contact = [contactEnumerator nextObject]) != nil) {
		[delegates broadcastSelector: @selector(contactManager:
						  didRemoveContact:)
				  withObject: self
				  withObject: contact];
	}
	[contacts release];

	contacts = [[OFMutableDictionary alloc] init];
	rosterItems = [roster_ rosterItems];
	rosterItemEnumerator = [rosterItems keyEnumerator];
	while ((bareJID = [rosterItemEnumerator nextObject]) != nil) {
		contact = [[XMPPContact new] autorelease];
		[contact XMPP_setRosterItem:
		    [rosterItems objectForKey: bareJID]];
		[contacts setObject: contact
			     forKey: bareJID];
		[delegates broadcastSelector: @selector(contactManager:
						  didAddContact:)
				  withObject: self
				  withObject: contact];
	}
}

-         (void)roster: (XMPPRoster*)roster
  didReceiveRosterItem: (XMPPRosterItem*)rosterItem
{
	XMPPContact *contact;
	OFString *bareJID = [[rosterItem JID] bareJID];

	contact = [contacts objectForKey: bareJID];

	if ([[rosterItem subscription] isEqual: @"remove"]) {
		[contacts removeObjectForKey: bareJID];
		if (contact != nil)
			[delegates broadcastSelector: @selector(contactManager:
							  didRemoveContact:)
					  withObject: self
					  withObject: contact];
		return;
	}

	if (contact == nil) {
		contact = [[XMPPContact new] autorelease];
		[contact XMPP_setRosterItem: rosterItem];
		[contacts setObject: contact
			     forKey: bareJID];
		[delegates broadcastSelector: @selector(contactManager:
						  didAddContact:)
				  withObject: self
				  withObject: contact];
	} else {
		[delegates broadcastSelector: @selector(contact:
						  willUpdateWithRosterItem:)
				  withObject: contact
				  withObject: rosterItem];
		[contact XMPP_setRosterItem: rosterItem];
	}
}

-   (void)connection: (XMPPConnection*)connection
  didReceivePresence: (XMPPPresence*)presence
{
	XMPPJID *JID = [presence from];
	XMPPContact *contact = [contacts objectForKey: [JID bareJID]];

	if (contact == nil)
		return;

	// We only care for available and unavailable here, not subscriptions
	if ([[presence type] isEqual: @"available"]) {
		[contact XMPP_setPresence: presence
				 resource: [JID resource]];
		[delegates broadcastSelector: @selector(contact:
						  didSendPresence:)
				  withObject: contact
				  withObject: presence];
	} else if ([[presence type] isEqual: @"unavailable"]) {
		[contact XMPP_removePresenceForResource: [JID resource]];
		[delegates broadcastSelector: @selector(contact:
						  didSendPresence:)
				  withObject: contact
				  withObject: presence];
	}
}

-  (void)connection: (XMPPConnection*)connection
  didReceiveMessage: (XMPPMessage*)message
{
	XMPPJID *JID = [message from];
	XMPPContact *contact = [contacts objectForKey: [JID bareJID]];

	if (contact == nil)
		return;

	[contact XMPP_setLockedOnJID: JID];

	[delegates broadcastSelector: @selector(contact:didSendMessage:)
			  withObject: contact
			  withObject: message];
}
@end