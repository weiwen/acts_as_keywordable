# ActsAsKeywordable
module CC
  module Acts 
    module Keywordable 

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_keywordable(options={})
          ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
          keyword_classname = options[:keyword_classname] || ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s + "Keyword"
          has_many :keywords, :class_name=>keyword_classname, :dependent => :destroy

          include CC::Acts::Keywordable::InstanceMethods
          extend CC::Acts::Keywordable::SingletonMethods
        end
      end

      module SingletonMethods
        # Add class methods here
        # find all objects with the keyword order by the frequency of the keyword is used on the object
        # e.g. Graphic.find(1).keywords = ["music", "piano"]
        # Graphic.find(2).keywords = ["music", "guitar", "music"]
        # Graphic.find(3).keyword = ["new york"]
        # Graphic.for_keyword('music') => [#<Graphic id: 2>, #<Graphic id:3>]
        def for_keyword(kwd, by='count', options={})
          keyword_table =  reflections[:keywords].table_name
          foreign_key = self.name.downcase + '_id'
          order = by=='count'? "#{keyword_table}.count DESC" : ''
          query_options = { :select => "#{table_name}.*",
            :joins => "INNER JOIN #{keyword_table} ON #{keyword_table}.#{foreign_key} = #{table_name}.#{primary_key}",      
            :conditions => sanitize_sql(["#{keyword_table}.keyword = ?", kwd]),
            :order => order
          }.update(options)
          find(:all, query_options)
        end
        
        # return the most used keyword order by the number of objects that contain the keyword
        # Graphic.top_keywords(10) => [{:keyword=>"music", :count=>2}, {:keyword=>"piano", :count=>1}]
        def top_keywords(limit, offset=0)
          keyword_table =  reflections[:keywords].table_name
          sql = %Q{
              SELECT keyword, count(*) AS cnt
                FROM  #{keyword_table}
                GROUP BY keyword
                ORDER BY cnt DESC
                LIMIT #{limit} 
                OFFSET #{offset}
          }
          connection.select_all(sql).map{|row| {:keyword=>row['keyword'], :count=>row['cnt']}}
        end
        
        # return the related keywords
        # Graphic.related_keywords('music') => [{:keyword=>"piano", :count=>1}, {:keyword=>"guitar", :count=>1}]
        def related_keywords(kwd, limit=100)
          keyword_table =  reflections[:keywords].table_name
          foreign_key = self.name.downcase + '_id'
          condition = sanitize_sql(["keyword = ?", kwd])
          negative_condition = sanitize_sql(["keyword != ?", kwd])
          sub_query = "SELECT #{foreign_key} FROM #{keyword_table} WHERE #{condition} ORDER BY count DESC LIMIT 50"
          id_list = connection.select_all(sub_query).map{|x| x[foreign_key]}
          if id_list.empty?
            return id_list
          else
            ids_str = id_list.join(',')
            puts ids_str
            sql = %Q{
                SELECT keyword, count(*) as cnt
                FROM #{keyword_table}
                WHERE #{foreign_key} in (#{ids_str}) AND #{negative_condition}
                GROUP BY keyword
                ORDER BY cnt DESC
                LIMIT #{limit}
            }
            connection.select_all(sql).map{|row| {:keyword=>row['keyword'], :count=>row['cnt']}}
          end
        end
        
      end

      module InstanceMethods
        # Add instance methods here
        
        def add_keyword(kwd, max_len=25) 
          kwd.strip!
          return if (kwd.blank? || kwd.size > 25)
          kwd = keywords.find_or_create_by_keyword(kwd)
          kwd.increment! :count
        end
      end
    end
  end
end

