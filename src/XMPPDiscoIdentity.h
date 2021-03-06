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

#import <ObjFW/ObjFW.h>

/**
 * \brief A class describing a Service Discovery Identity
 */
@interface XMPPDiscoIdentity: OFObject <OFComparing>
{
	OFString *_category;
	OFString *_name;
	OFString *_type;
}
#ifdef OF_HAVE_PROPERTIES
/// \brief The category of the identity
@property (readonly) OFString *category;
/// \brief The name of the identity, might be unset
@property (readonly) OFString *name;
/// \brief The type of the identity
@property (readonly) OFString *type;
#endif

/**
 * \brief Creates a new autoreleased XMPPDiscoIdentity with the specified
 *	  category, type and name.
 *
 * \param category The category of the identity
 * \param type The type of the identity
 * \param name The name of the identity
 * \return A new autoreleased XMPPDiscoIdentity
 */
+ identityWithCategory: (OFString*)category
		  type: (OFString*)type
		  name: (OFString*)name;

/**
 * \brief Creates a new autoreleased XMPPDiscoIdentity with the specified
 *	  category and type.
 *
 * \param category The category of the identity
 * \param type The type of the identity
 * \return A new autoreleased XMPPDiscoIdentity
 */
+ identityWithCategory: (OFString*)category
		  type: (OFString*)type;

/**
 * \brief Initializes an already allocated XMPPDiscoIdentity with the specified
 *	  category, type and name.
 *
 * \param category The category of the identity
 * \param type The type of the identity
 * \param name The name of the identity
 * \return An initialized XMPPDiscoIdentity
 */
- initWithCategory: (OFString*)category
	      type: (OFString*)type
	      name: (OFString*)name;

/**
 * \brief Initializes an already allocated XMPPDiscoIdentity with the specified
 *	  category and type.
 *
 * \param category The category of the identity
 * \param type The type of the identity
 * \return An initialized XMPPDiscoIdentity
 */
- initWithCategory: (OFString*)category
	      type: (OFString*)type;

- (OFString*)category;
- (OFString*)name;
- (OFString*)type;
@end
