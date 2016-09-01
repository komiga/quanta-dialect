
include = {
	\\ group roots
	\\ e.g.,
	\\ "chemical/root.q" \\ (from core/data/entity)
}

\\ structure example
\*

top_level_category = GenericCategory{
	d = "top-level category"
	author = "The Queen"
children = {
	\\ ref: top_level_category.x
	x = Generic{
		d = "generic entity"
	sources = {
		\\ ref: top_level_category.x$1
		1 {
			d = _ + " - $1"
		sub_sources = {
			\\ ref: top_level_category.x$1$1
			1 {
				d = _ + " - $1"
			}
		}}
	}
	children = {
		y = Generic{d = "..."}
	}}
}}

*\
