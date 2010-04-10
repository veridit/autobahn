#!/usr/bin/env ruby
#
# 
require 'pp'

quoted_regexps = [ Regexp.new(Regexp.quote "PROCEDURAL LANGUAGE - plpgsql postgres")]

# Dump reference dump template1 
%x{pg_dump -Fc template1 > tmp/template1.pgdump}
%x{pg_restore --list tmp/template1.pgdump > tmp/template1.pgdump.list}

# Create template_gis
%x{sudo -u postgres psql -c "create database template_gis;"}
%x{sudo -u postgres psql template_gis -c "create language plpgsql;"}
%x{sudo -u postgres psql template_gis -f /usr/share/postgresql/8.4/contrib/postgis.sql}
%x{sudo -u postgres psql template_gis -f /usr/share/postgresql/8.4/contrib/postgis_comments.sql}
%x{sudo -u postgres psql template_gis -c "grant all on geometry_columns to public;"}
%x{sudo -u postgres psql template_gis -c "grant select on spatial_ref_sys to public;"}
# Dump and compare template_gis with template1
%x{pg_dump -Fc template_gis > tmp/template_gis.pgdump}
%x{pg_restore --list tmp/template_gis.pgdump > tmp/template_gis.pgdump.list}
%x{diff --left-column --suppress-common-lines --ignore-matching-lines='^;' tmp/template_gis.pgdump.list tmp/template1.pgdump.list > tmp/template_gis.diff}
%x{sudo -u postgres psql -c "drop database template_gis;"}

# Create template_pg_trgm
%x{sudo -u postgres psql -c "create database template_pg_trgm;"}
%x{sudo -u postgres psql template_pg_trgm -c "create language plpgsql;"}
%x{sudo -u postgres psql template_pg_trgm -f /usr/share/postgresql/8.4/contrib/pg_trgm.sql}
# Dump and compare template_pg_trgm with template1
%x{pg_dump -Fc template_pg_trgm > tmp/template_pg_trgm.pgdump}
%x{pg_restore --list tmp/template_pg_trgm.pgdump > tmp/template_pg_trgm.pgdump.list}
%x{diff --left-column --suppress-common-lines --ignore-matching-lines='^;' tmp/template_pg_trgm.pgdump.list tmp/template1.pgdump.list > tmp/template_pg_trgm.diff}
%x{sudo -u postgres psql -c "drop database template_pg_trgm;"}

# Create template_ltree
%x{sudo -u postgres psql -c "create database template_ltree;"}
%x{sudo -u postgres psql template_ltree -c "create language plpgsql;"}
%x{sudo -u postgres psql template_ltree -f /usr/share/postgresql/8.4/contrib/ltree.sql}
# Dump and compare template_ltree with template1
%x{pg_dump -Fc template_ltree > tmp/template_ltree.pgdump}
%x{pg_restore --list tmp/template_ltree.pgdump > tmp/template_ltree.pgdump.list}
%x{diff --left-column --suppress-common-lines --ignore-matching-lines='^;' tmp/template_ltree.pgdump.list tmp/template1.pgdump.list > tmp/template_ltree.diff}
%x{sudo -u postgres psql -c "drop database template_ltree;"}

# Create template_intarray
%x{sudo -u postgres psql -c "create database template_intarray;"}
%x{sudo -u postgres psql template_intarray -c "create language plpgsql;"}
%x{sudo -u postgres psql template_intarray -f /usr/share/postgresql/8.4/contrib/_int.sql}
# Dump and compare template_intarray with template1
%x{pg_dump -Fc template_intarray > tmp/template_intarray.pgdump}
%x{pg_restore --list tmp/template_intarray.pgdump > tmp/template_intarray.pgdump.list}
%x{diff --left-column --suppress-common-lines --ignore-matching-lines='^;' tmp/template_intarray.pgdump.list tmp/template1.pgdump.list > tmp/template_intarray.diff}
%x{sudo -u postgres psql -c "drop database template_intarray;"}

["tmp/template_gis.diff","tmp/template_pg_trgm.diff","tmp/template_ltree.diff","tmp/template_intarray.diff"].each do |filename|
  # Use diff to generate regexps for lines to ignore on restore
  File.open(filename) do |file|
    file.each do |line|
      case line when /^< \d+; \d+ \d+ (.*)$/ then 
        candidate = $1
        case candidate 
        when /constraint/i,/table/i,/cast/i,/aggregate/i,/shell/i,/type/i,/acl/i,/function/i,/operator/i then 
          quoted_regexps << Regexp.quote(candidate)
        end 
      end
    end
  end
end

regexps = quoted_regexps.map{|quoted_rexep| Regexp.new(quoted_rexep)}

template = <<-EOS
#!/usr/bin/env ruby
#

REGEXPS = #{regexps.pretty_inspect}

$stdin.each_line do |line|
  if REGEXPS.inject(nil) do |found,pattern|
    unless found then
      if line =~ pattern then
        found = true
      end
    end
    found
  end then
    # Ignore elements provided by already postgis enabled template database
  else
    puts line # This line is NOT part of template_gis
  end
end 
EOS

generated_filename = __FILE__.sub("/generate_","/")
File.open(generated_filename,'w+') do |file|
  file.write template
end
