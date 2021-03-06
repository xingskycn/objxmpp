/*
 * Copyright (c) 2011, Florian Zeitz <florob@babelmonkeys.de>
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

#include <netinet/in.h>
#include <arpa/nameser.h>
#include <resolv.h>

#import <ObjFW/ObjFW.h>

@interface XMPPSRVEntry: OFObject
{
	uint16_t _priority;
	uint16_t _weight;
	uint32_t _accumulatedWeight;
	uint16_t _port;
	OFString *_target;
}

#ifdef OF_HAVE_PROPERTIES
@property (readonly) uint16_t priority;
@property (readonly) uint16_t weight;
@property uint32_t accumulatedWeight;
@property (readonly) uint16_t port;
@property (readonly, copy) OFString *target;
#endif

+ entryWithPriority: (uint16_t)priority
	     weight: (uint16_t)weight
	       port: (uint16_t)port
	     target: (OFString*)target;
+ entryWithResourceRecord: (ns_rr)resourceRecord
		   handle: (ns_msg)handle;
- initWithPriority: (uint16_t)priority
	    weight: (uint16_t)weight
	      port: (uint16_t)port
	    target: (OFString*)target;
- initWithResourceRecord: (ns_rr)resourceRecord
		  handle: (ns_msg)handle;
- (uint16_t)priority;
- (uint16_t)weight;
- (uint32_t)accumulatedWeight;
- (void)setAccumulatedWeight: (uint32_t)accumulatedWeight;
- (uint16_t)port;
- (OFString*)target;
@end

@interface XMPPSRVLookup: OFObject <OFEnumerating>
{
	OFString *_domain;
	struct __res_state _resState;
	OFList *_list;
}

#ifdef OF_HAVE_PROPERTIES
@property (readonly, copy) OFString *domain;
#endif

+ lookupWithDomain: (OFString*)domain;
- initWithDomain: (OFString*)domain;

- (void)XMPP_lookup;
- (void)XMPP_addEntry: (XMPPSRVEntry*)item;
@end

@interface XMPPSRVEnumerator: OFEnumerator
{
	OFList *list;
	of_list_object_t *listIter;
	OFList *subListCopy;
	BOOL done;
}

- initWithList: (OFList*)list;
@end
