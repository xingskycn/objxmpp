/*
 * Copyright (c) 2011, Jonathan Schleifer <js@webkeks.org>
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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <assert.h>

#include <arpa/inet.h>
#include <netdb.h>
#include <sys/types.h>
#include <openssl/rand.h>

#import "XMPPSRVLookup.h"

@implementation XMPPSRVEntry
+ entryWithPriority: (uint16_t)priority
	     weight: (uint16_t)weight
	       port: (uint16_t)port
	     target: (OFString*)target
{
	return [[[self alloc] initWithPriority: priority
					weight: weight
					  port: port
					target: target] autorelease];
}

+ entryWithResourceRecord: (ns_rr)resourceRecord
		   handle: (ns_msg)handle
{
	return [[[self alloc] initWithResourceRecord: resourceRecord
					      handle: handle] autorelease];
}

- init
{
	Class c = [self class];
	[self release];
	@throw [OFNotImplementedException exceptionWithClass: c
						    selector: _cmd];
}

- initWithPriority: (uint16_t)priority
	    weight: (uint16_t)weight
	      port: (uint16_t)port
	    target: (OFString*)target
{
	self = [super init];

	@try {
		_priority = priority;
		_weight = weight;
		_port = port;
		_target = [target copy];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithResourceRecord: (ns_rr)resourceRecord
		  handle: (ns_msg)handle
{
	self = [super init];

	@try {
		const uint16_t *rdata;
		char buffer[NS_MAXDNAME];

		rdata = (const uint16_t*)(void*)ns_rr_rdata(resourceRecord);
		_priority = ntohs(rdata[0]);
		_weight = ntohs(rdata[1]);
		_port = ntohs(rdata[2]);

		if (dn_expand(ns_msg_base(handle), ns_msg_end(handle),
		    (uint8_t*)&rdata[3], buffer, NS_MAXDNAME) < 1)
			@throw [OFInitializationFailedException
			    exceptionWithClass: [self class]];

		_target = [[OFString alloc]
		    initWithCString: buffer
			   encoding: OF_STRING_ENCODING_NATIVE];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_target release];

	[super dealloc];
}

- (OFString*)description
{
	return [OFString stringWithFormat:
	    @"<%@ priority: %" PRIu16 @", weight: %" PRIu16 @", target: %@:%"
	    PRIu16 @">", [self class], _priority, _weight, _target, _port];
}

- (uint16_t)priority
{
	return _priority;
}

- (uint16_t)weight
{
	return _weight;
}

- (void)setAccumulatedWeight: (uint32_t)accumulatedWeight
{
	_accumulatedWeight = accumulatedWeight;
}

- (uint32_t)accumulatedWeight
{
	return _accumulatedWeight;
}

- (uint16_t)port
{
	return _port;
}

- (OFString*)target
{
	OF_GETTER(_target, YES)
}
@end

@implementation XMPPSRVLookup
+ lookupWithDomain: (OFString*)domain
{
	return [[[self alloc] initWithDomain: domain] autorelease];
}

- initWithDomain: (OFString*)domain
{
	self = [super init];

	@try {
		_list = [[OFList alloc] init];
		_domain = [domain copy];

		[self XMPP_lookup];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_list release];
	[_domain release];

	[super dealloc];
}

- (OFString*)domain;
{
	OF_GETTER(_domain, YES)
}

- (void)XMPP_lookup
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	unsigned char *answer = NULL;
	size_t pageSize = [OFSystemInfo pageSize];
	OFString *request;

	request = [OFString stringWithFormat: @"_xmpp-client._tcp.%@", _domain];

	@try {
		int answerLen, resourceRecordCount, i;
		ns_rr resourceRecord;
		ns_msg handle;

		if (res_ninit(&_resState))
			@throw [OFAddressTranslationFailedException
			    exceptionWithClass: [self class]
					socket: nil
					  host: _domain];

		answer = [self allocMemoryWithSize: pageSize];
		answerLen = res_nsearch(&_resState,
		    [request cStringWithEncoding: OF_STRING_ENCODING_NATIVE],
		    ns_c_in, ns_t_srv, answer, (int)pageSize);

		if ((answerLen == -1) && ((h_errno == HOST_NOT_FOUND) ||
		    (h_errno == NO_DATA)))
			return;

		if (answerLen < 1 || answerLen > pageSize) {
			@throw [OFAddressTranslationFailedException
			    exceptionWithClass: [self class]
					socket: nil
					  host: _domain];
		}

		if (ns_initparse(answer, answerLen, &handle))
			@throw [OFAddressTranslationFailedException
			    exceptionWithClass: [self class]
					socket: nil
					  host: _domain];

		resourceRecordCount = ns_msg_count(handle, ns_s_an);
		for (i = 0; i < resourceRecordCount; i++) {
			if (ns_parserr(&handle, ns_s_an, i, &resourceRecord))
				continue;

			if (ns_rr_type(resourceRecord) != ns_t_srv ||
			    ns_rr_class(resourceRecord) != ns_c_in)
				continue;

			[self XMPP_addEntry: [XMPPSRVEntry
			    entryWithResourceRecord: resourceRecord
					     handle: handle]];
		}
	} @finally {
		[self freeMemory: answer];
#ifdef HAVE_RES_NDESTROY
		res_ndestroy(&_resState);
#endif
	}

	[pool release];
}

- (void)XMPP_addEntry: (XMPPSRVEntry*)entry
{
	OFAutoreleasePool *pool;
	OFList *subList;
	of_list_object_t *iter;

	/* Look if there already is a list with the priority */
	for (iter = [_list firstListObject]; iter != NULL; iter = iter->next) {
		if ([[iter->object firstObject] priority] == [entry priority]) {
			/*
			 * RFC 2782 says those with weight 0 should be at the
			 * beginning of the list.
			 */
			if ([entry weight] > 0)
				[iter->object appendObject: entry];
			else
				[iter->object prependObject: entry];

			return;
		}

		/* We can't have one if the priority is already bigger */
		if ([[iter->object firstObject] priority] > [entry priority])
			break;
	}

	pool = [[OFAutoreleasePool alloc] init];

	subList = [OFList list];
	[subList appendObject: entry];

	if (iter != NULL)
		[_list insertObject: subList
		   beforeListObject: iter];
	else
		[_list appendObject: subList];

	[pool release];
}

- (OFEnumerator*)objectEnumerator
{
	return [[[XMPPSRVEnumerator alloc] initWithList: _list] autorelease];
}
@end

@implementation XMPPSRVEnumerator
- initWithList: (OFList*)list_
{
	self = [super init];

	@try {
		list = [list_ copy];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (id)nextObject
{
	XMPPSRVEntry *ret = nil;
	of_list_object_t *iter;
	uint32_t totalWeight = 0;

	if (done)
		return nil;

	if (listIter == NULL)
		listIter = [list firstListObject];

	if (listIter == NULL)
		return nil;

	if (subListCopy == nil)
		subListCopy = [listIter->object copy];

	for (iter = [subListCopy firstListObject]; iter != NULL;
	     iter = iter->next) {
		totalWeight += [iter->object weight];
		[iter->object setAccumulatedWeight: totalWeight];
	}

	if ([subListCopy count] > 0)  {
		uint32_t randomWeight;

		RAND_pseudo_bytes((uint8_t*)&randomWeight, sizeof(uint32_t));
		randomWeight %= (totalWeight + 1);

		for (iter = [subListCopy firstListObject]; iter != NULL;
		     iter = iter->next) {
			if ([iter->object accumulatedWeight] >= randomWeight) {
				ret = [[iter->object retain] autorelease];

				[subListCopy removeListObject: iter];

				break;
			}
		}
	}

	if ([subListCopy count] == 0) {
		[subListCopy release];
		subListCopy = nil;

		listIter = listIter->next;

		if (listIter == NULL)
			done = YES;
	}

	return ret;
}

- (void)reset
{
	listIter = NULL;
	[subListCopy release];
	subListCopy = nil;
	done = NO;
}
@end
