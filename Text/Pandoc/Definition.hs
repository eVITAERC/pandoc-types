{-# LANGUAGE DeriveDataTypeable, DeriveGeneric, FlexibleContexts #-}

{-
Copyright (C) 2006-2013 John MacFarlane <jgm@berkeley.edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module      : Text.Pandoc.Definition
   Copyright   : Copyright (C) 2006-2010 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Definition of 'Pandoc' data structure for format-neutral representation
of documents.
-}
module Text.Pandoc.Definition ( Pandoc(..)
                              , Meta(..)
                              , MetaValue(..)
                              , nullMeta
                              , isNullMeta
                              , lookupMeta
                              , docTitle
                              , docAuthors
                              , docDate
                              , Block(..)
                              , Inline(..)
                              , Alignment(..)
                              , ListAttributes
                              , ListNumberStyle(..)
                              , ListNumberDelim(..)
                              , Format(..)
                              , Attr
                              , nullAttr
                              , TableCell
                              , QuoteType(..)
                              , Target
                              , MathType(..)
                              , FigureType(..)
                              , PreparedContent(..)
                              , noPrepContent
                              , StatementAttr(..)
                              , StatementStyle(..)
                              , Citation(..)
                              , CitationMode(..)
                              , NumberedReference(..)
                              , NumberedReferenceStyle(..)
                              ) where

import Data.Generics (Data, Typeable)
import Data.Ord (comparing)
import Data.Aeson (FromJSON(..), ToJSON(..))
import qualified Data.Aeson.Types as Aeson
import Control.Monad (guard)
import qualified Data.Map as M
import GHC.Generics (Generic, Rep (..))
import Data.String
import Data.Char (toLower)
import Data.Monoid
import Control.DeepSeq.Generics

data Pandoc = Pandoc Meta [Block]
              deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)

instance Monoid Pandoc where
  mempty = Pandoc mempty mempty
  (Pandoc m1 bs1) `mappend` (Pandoc m2 bs2) =
    Pandoc (m1 `mappend` m2) (bs1 `mappend` bs2)

-- | Metadata for the document:  title, authors, date.
newtype Meta = Meta { unMeta :: M.Map String MetaValue }
               deriving (Eq, Ord, Show, Read, Typeable, Data, Generic)

instance Monoid Meta where
  mempty = Meta (M.empty)
  (Meta m1) `mappend` (Meta m2) = Meta (M.union m1 m2)
  -- note: M.union is left-biased, so if there are fields in both m1
  -- and m2, m1 wins.

data MetaValue = MetaMap (M.Map String MetaValue)
               | MetaList [MetaValue]
               | MetaBool Bool
               | MetaString String
               | MetaInlines [Inline]
               | MetaBlocks [Block]
               deriving (Eq, Ord, Show, Read, Typeable, Data, Generic)

nullMeta :: Meta
nullMeta = Meta M.empty

isNullMeta :: Meta -> Bool
isNullMeta (Meta m) = M.null m

-- Helper functions to extract metadata

-- | Retrieve the metadata value for a given @key@.
lookupMeta :: String -> Meta -> Maybe MetaValue
lookupMeta key (Meta m) = M.lookup key m

-- | Extract document title from metadata; works just like the old @docTitle@.
docTitle :: Meta -> [Inline]
docTitle meta =
  case lookupMeta "title" meta of
         Just (MetaString s)           -> [Str s]
         Just (MetaInlines ils)        -> ils
         Just (MetaBlocks [Plain ils]) -> ils
         Just (MetaBlocks [Para ils])  -> ils
         _                             -> []

-- | Extract document authors from metadata; works just like the old
-- @docAuthors@.
docAuthors :: Meta -> [[Inline]]
docAuthors meta =
  case lookupMeta "author" meta of
        Just (MetaString s)    -> [[Str s]]
        Just (MetaInlines ils) -> [ils]
        Just (MetaList   ms)   -> [ils | MetaInlines ils <- ms] ++
                                  [ils | MetaBlocks [Plain ils] <- ms] ++
                                  [ils | MetaBlocks [Para ils]  <- ms] ++
                                  [[Str x] | MetaString x <- ms]
        _                      -> []

-- | Extract date from metadata; works just like the old @docDate@.
docDate :: Meta -> [Inline]
docDate meta =
  case lookupMeta "date" meta of
         Just (MetaString s)           -> [Str s]
         Just (MetaInlines ils)        -> ils
         Just (MetaBlocks [Plain ils]) -> ils
         Just (MetaBlocks [Para ils])  -> ils
         _                             -> []

-- | Alignment of a table column.
data Alignment = AlignLeft
               | AlignRight
               | AlignCenter
               | AlignDefault deriving (Eq, Ord, Show, Read, Typeable, Data, Generic)

-- | List attributes.
type ListAttributes = (Int, ListNumberStyle, ListNumberDelim)

-- | Style of list numbers.
data ListNumberStyle = DefaultStyle
                     | Example
                     | Decimal
                     | LowerRoman
                     | UpperRoman
                     | LowerAlpha
                     | UpperAlpha deriving (Eq, Ord, Show, Read, Typeable, Data, Generic)

-- | Delimiter of list numbers.
data ListNumberDelim = DefaultDelim
                     | Period
                     | OneParen
                     | TwoParens deriving (Eq, Ord, Show, Read, Typeable, Data, Generic)

-- | Attributes: identifier, classes, key-value pairs
type Attr = (String, [String], [(String, String)])

nullAttr :: Attr
nullAttr = ("",[],[])

-- | Table cells are list of Blocks
type TableCell = [Block]

-- | Formats for raw blocks
newtype Format = Format String
               deriving (Read, Show, Typeable, Data, Generic)

instance IsString Format where
  fromString f = Format $ map toLower f

instance Eq Format where
  Format x == Format y = map toLower x == map toLower y

instance Ord Format where
  compare (Format x) (Format y) = compare (map toLower x) (map toLower y)

-- | Block element.
data Block
    = Plain [Inline]        -- ^ Plain text, not a paragraph
    | Para [Inline]         -- ^ Paragraph
    | CodeBlock Attr String -- ^ Code block (literal) with attributes
    | RawBlock Format String -- ^ Raw block
    | BlockQuote [Block]    -- ^ Block quote (list of blocks)
    | OrderedList ListAttributes [[Block]] -- ^ Ordered list (attributes
                            -- and a list of items, each a list of blocks)
    | BulletList [[Block]]  -- ^ Bullet list (list of items, each
                            -- a list of blocks)
    | DefinitionList [([Inline],[[Block]])]  -- ^ Definition list
                            -- Each list item is a pair consisting of a
                            -- term (a list of inlines) and one or more
                            -- definitions (each a list of blocks)
    | Header Int Attr [Inline] -- ^ Header - level (integer) and text (inlines)
    | HorizontalRule        -- ^ Horizontal rule
    | Table [Inline] [Alignment] [Double] [TableCell] [[TableCell]]  -- ^ Table,
                            -- with caption, column alignments (required),
                            -- relative column widths (0 = default),
                            -- column headers (each a list of blocks), and
                            -- rows (each a list of lists of blocks)
    | Figure FigureType Attr [Block] PreparedContent [Inline] -- ^ A floating figure,
                            -- containing for example images, tables,
                            -- highlighted code, pseudocode, etc. Differentiated
                            -- by FigureType. Has attribures, list of float
                            -- content (typically just 1), a FloatFallback for
                            -- "pre-compiled" float content,and a caption (inlines)
                            -- for the whole figure.
    | ImageGrid [[Inline]]  -- ^ ImageGrid, containing rows of images, intended
                            -- to be used primarily in Floats. In this context,
                            -- alt texts will be treated as captions for each
                            -- individual image.
    | Statement StatementAttr [Block] -- ^ Standalone statements, can be
                            -- sequentially numbered and cross-referenced, and
                            -- optinally may have a Proof block inside its body.
    | Proof [Inline] [Block] -- ^ Proofs (AMS-style), with an optional
                            -- alternate title, and proof text
    | Div Attr [Block]      -- ^ Generic block container with attributes
    | Null                  -- ^ Nothing
    deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)

-- | Type of figure, mainly used to differentiate content (i.e., images vs tables).
--   ImageFigure contains a ImageGrid. TableFigure contains one or more Tables.
--   LineBlockFigure contains one or more Paras (intended for algorithms and poetry).
--   ListingFigure contains one or more CodeBlocks.
data FigureType = ImageFigure | TableFigure | LineBlockFigure | ListingFigure
     deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

-- | Type of quotation marks to use in Quoted inline.
data QuoteType = SingleQuote | DoubleQuote deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

-- | Link target (URL, title).
type Target = (String, String)

-- | Type of math element (display or inline).
data MathType = DisplayMath Attr | InlineMath deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

-- | Pre-rendered figure content intended to archive final, professionally typeset or drawn
--   figures from content already described in markdown format (an image and/or latex code)
data PreparedContent = PreparedContent { preparedImageContent :: Inline -- Image
                                       , preparedLaTeXContent :: String
                                        }
     deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

noPrepContent :: PreparedContent
noPrepContent = PreparedContent Space ""

-- | Statement Attributes: identifier, label (inlines with raw), name of counter, hiearchy level, pre-computed numerical label, caption,
data StatementAttr  = StatementAttr { statementId      :: String
                                    , statementStyle   :: StatementStyle
                                    , statementLabel   :: ([Inline], String)
                                    , statementCounter :: String
                                    , statementLevel   :: Int
                                    , statementNum     :: String
                                    , statementCaption :: [Inline]
                                    }
     deriving (Show, Eq, Read, Typeable, Data, Generic)

instance Ord StatementAttr where
    compare = comparing statementId

-- | Type of statement, rought equivalent to @amsthm@ plain, defninition, and remark
data StatementStyle = Theorem | Standard | Remark | Other String
                      deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

-- | Inline elements.
data Inline
    = Str String            -- ^ Text (string)
    | Emph [Inline]         -- ^ Emphasized text (list of inlines)
    | Strong [Inline]       -- ^ Strongly emphasized text (list of inlines)
    | Strikeout [Inline]    -- ^ Strikeout text (list of inlines)
    | Superscript [Inline]  -- ^ Superscripted text (list of inlines)
    | Subscript [Inline]    -- ^ Subscripted text (list of inlines)
    | SmallCaps [Inline]    -- ^ Small caps text (list of inlines)
    | Quoted QuoteType [Inline] -- ^ Quoted text (list of inlines)
    | Cite [Citation]  [Inline] -- ^ Citation (list of inlines)
    | NumRef NumberedReference String -- ^ Reference (literal)
    | Code Attr String      -- ^ Inline code (literal)
    | Space                 -- ^ Inter-word space
    | LineBreak             -- ^ Hard line break
    | Math MathType String  -- ^ TeX math (literal)
    | RawInline Format String -- ^ Raw inline
    | Link [Inline] Target  -- ^ Hyperlink: text (list of inlines), target
    | Image Attr [Inline] Target -- ^ Image  alt text (list of inlines), target
    | Note [Block]          -- ^ Footnote or endnote
    | Span Attr [Inline]    -- ^ Generic inline container with attributes
    deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

data Citation = Citation { citationId      :: String
                         , citationPrefix  :: [Inline]
                         , citationSuffix  :: [Inline]
                         , citationMode    :: CitationMode
                         , citationNoteNum :: Int
                         , citationHash    :: Int
                         }
                deriving (Show, Eq, Read, Typeable, Data, Generic)

instance Ord Citation where
    compare = comparing citationHash

data CitationMode = AuthorInText | SuppressAuthor | NormalCitation
                    deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

data NumberedReference = NumberedReference { numRefId    :: String
                                           , numRefStyle :: NumberedReferenceStyle
                                           , numRefLabel :: [Inline]
                                           }
                         deriving (Show, Eq, Read, Typeable, Data, Generic)

instance Ord NumberedReference where
    compare = comparing numRefId

data NumberedReferenceStyle = PlainNumRef | ParenthesesNumRef
                              deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)

-- derive generic instances of FromJSON, ToJSON:

jsonOpts :: Aeson.Options
jsonOpts = Aeson.Options{ Aeson.fieldLabelModifier = id
                        , Aeson.constructorTagModifier = id
                        , Aeson.allNullaryToStringTag = False
                        , Aeson.omitNothingFields = False
                        , Aeson.sumEncoding = Aeson.TaggedObject "t" "c"
                        }

toJSON' :: (Generic a, Aeson.GToJSON (Rep a))
        => a -> Aeson.Value
toJSON' = Aeson.genericToJSON jsonOpts

parseJSON' :: (Generic a, Aeson.GFromJSON (Rep a))
           => Aeson.Value -> Aeson.Parser a
parseJSON' = Aeson.genericParseJSON jsonOpts

instance FromJSON MetaValue
  where parseJSON = parseJSON'
instance ToJSON MetaValue
  where toJSON = toJSON'

instance FromJSON Meta
  where parseJSON = parseJSON'
instance ToJSON Meta
  where toJSON = toJSON'

instance FromJSON CitationMode
  where parseJSON = parseJSON'
instance ToJSON CitationMode
  where toJSON = toJSON'

instance FromJSON Citation
  where parseJSON = parseJSON'
instance ToJSON Citation
  where toJSON = toJSON'

instance FromJSON NumberedReferenceStyle
  where parseJSON = parseJSON'
instance ToJSON NumberedReferenceStyle
  where toJSON = toJSON'

instance FromJSON NumberedReference
  where parseJSON = parseJSON'
instance ToJSON NumberedReference
  where toJSON = toJSON'

instance FromJSON FigureType
  where parseJSON = parseJSON'
instance ToJSON FigureType
  where toJSON = toJSON'

instance FromJSON PreparedContent
  where parseJSON = parseJSON'
instance ToJSON PreparedContent
  where toJSON = toJSON'

instance FromJSON StatementAttr
  where parseJSON = parseJSON'
instance ToJSON StatementAttr
  where toJSON = toJSON'

instance FromJSON StatementStyle
  where parseJSON = parseJSON'
instance ToJSON StatementStyle
  where toJSON = toJSON'

instance FromJSON QuoteType
  where parseJSON = parseJSON'
instance ToJSON QuoteType
  where toJSON = toJSON'

instance FromJSON MathType
  where parseJSON = parseJSON'
instance ToJSON MathType
  where toJSON = toJSON'

instance FromJSON ListNumberStyle
  where parseJSON = parseJSON'
instance ToJSON ListNumberStyle
  where toJSON = toJSON'

instance FromJSON ListNumberDelim
  where parseJSON = parseJSON'
instance ToJSON ListNumberDelim
  where toJSON = toJSON'

instance FromJSON Alignment
  where parseJSON = parseJSON'
instance ToJSON Alignment
  where toJSON = toJSON'

instance FromJSON Format
  where parseJSON = parseJSON'
instance ToJSON Format
  where toJSON = toJSON'

instance FromJSON Inline
  where parseJSON = parseJSON'
instance ToJSON Inline
  where toJSON = toJSON'

instance FromJSON Block
  where parseJSON = parseJSON'
instance ToJSON Block
  where toJSON = toJSON'

instance FromJSON Pandoc
  where parseJSON = parseJSON'
instance ToJSON Pandoc
  where toJSON = toJSON'

-- Instances for deepseq
instance NFData MetaValue where rnf = genericRnf
instance NFData Meta where rnf = genericRnf
instance NFData Citation where rnf = genericRnf
instance NFData Alignment where rnf = genericRnf
instance NFData Inline where rnf = genericRnf
instance NFData FigureType where rnf = genericRnf
instance NFData MathType where rnf = genericRnf
instance NFData PreparedContent where rnf = genericRnf
instance NFData StatementAttr where rnf = genericRnf
instance NFData StatementStyle where rnf = genericRnf
instance NFData Format where rnf = genericRnf
instance NFData CitationMode where rnf = genericRnf
instance NFData NumberedReference where rnf = genericRnf
instance NFData NumberedReferenceStyle where rnf = genericRnf
instance NFData QuoteType where rnf = genericRnf
instance NFData ListNumberDelim where rnf = genericRnf
instance NFData ListNumberStyle where rnf = genericRnf
instance NFData Block where rnf = genericRnf
instance NFData Pandoc where rnf = genericRnf
