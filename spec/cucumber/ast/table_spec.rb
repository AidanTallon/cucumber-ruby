require File.dirname(__FILE__) + '/../../spec_helper'
require 'cucumber/ast/table'

module Cucumber
  module Ast
    describe Table do
      before do
        @table = Table.new([
          %w{one four seven},
          %w{4444 55555 666666}
        ])
        def @table.cells_rows; super; end
        def @table.columns; super; end
      end

      it "should have rows" do
        @table.cells_rows[0].map{|cell| cell.value}.should == %w{one four seven}
      end

      it "should have columns" do
        @table.columns[1].map{|cell| cell.value}.should == %w{four 55555}
      end

      it "should have headers" do
        @table.headers.should == %w{one four seven}
      end

      it "should have same cell objects in rows and columns" do
        # 666666
        @table.cells_rows[1].__send__(:[], 2).should equal(@table.columns[2].__send__(:[], 1))
      end

      it "should know about max width of a row" do
        @table.columns[1].__send__(:width).should == 5
      end

      it "should be convertible to an array of hashes" do
        @table.hashes.should == [
          {'one' => '4444', 'four' => '55555', 'seven' => '666666'}
        ]
      end

      it "should accept symbols as keys for the hashes" do
        @table.hashes.first[:one].should == '4444'
      end

      it "should allow map'ing columns" do
        @table.map_column!('one') { |v| v.to_i }
        @table.hashes.first['one'].should == 4444
      end

      it "should pass silently if a mapped column does not exist in non-strict mode" do
        lambda {
          @table.map_column!('two', false) { |v| v.to_i }
        }.should_not raise_error
      end

      it "should fail if a mapped column does not exist in strict mode" do
        lambda {
          @table.map_column!('two', true) { |v| v.to_i }
        }.should raise_error('The column named "two" does not exist')
      end

      describe "#transpose" do
        before(:each) do
          @table = Table.new([
            %w{one 1111},
            %w{two 22222}
          ])
        end
                
        it "should be convertible in to an array where each row is a hash" do 
          @table.transpose.hashes[0].should == {'one' => '1111', 'two' => '22222'}
        end
      end
      
      describe "#rows_hash" do
                
        it "should return a hash of the rows" do
          table = Table.new([
            %w{one 1111},
            %w{two 22222}
          ])
          table.rows_hash.should == {'one' => '1111', 'two' => '22222'}
        end
        
        it "should fail if the table doesn't have two columns" do
          faulty_table = Table.new([
            %w{one 1111 abc},
            %w{two 22222 def}
          ])
          lambda {
            faulty_table.rows_hash
          }.should raise_error('The table must have exactly 2 columns')
        end
      end
        
      it "should allow renaming columns" do
        table2 = @table.map_headers('one' => :three)
        table2.hashes.first[:three].should == '4444'
      end

      it "should copy column mappings when mapping headers" do
        @table.map_column!('one') { |v| v.to_i }
        table2 = @table.map_headers('one' => 'three')
        table2.hashes.first['three'].should == 4444
      end

      describe "replacing arguments" do

        before(:each) do
          @table = Table.new([
            %w{qty book},
            %w{<qty> <book>}
          ])
        end

        it "should return a new table with arguments replaced with values" do
          table_with_replaced_args = @table.arguments_replaced({'<book>' => 'Unbearable lightness of being', '<qty>' => '5'})

          table_with_replaced_args.hashes[0]['book'].should == 'Unbearable lightness of being'
          table_with_replaced_args.hashes[0]['qty'].should == '5'
        end

        it "should recognise when entire cell is delimited" do
          @table.should have_text('<book>')
        end

        it "should recognise when just a subset of a cell is delimited" do
          table = Table.new([
            %w{qty book},
            [nil, "This is <who>'s book"]
          ])
          table.should have_text('<who>')
        end

        it "should replace nil values with nil" do
          table_with_replaced_args = @table.arguments_replaced({'<book>' => nil})

          table_with_replaced_args.hashes[0]['book'].should == nil
        end

        it "should preserve values which don't match a placeholder when replacing with nil" do
          table = Table.new([
                              %w{book},
                              %w{cat}
                            ])
          table_with_replaced_args = table.arguments_replaced({'<book>' => nil})
          
          table_with_replaced_args.hashes[0]['book'].should == 'cat'
        end

        it "should not change the original table" do
          @table.arguments_replaced({'<book>' => 'Unbearable lightness of being'})

          @table.hashes[0]['book'].should_not == 'Unbearable lightness of being'
        end

        it "should not raise an error when there are nil values in the table" do
          table = Table.new([
                              ['book', 'qty'],
                              ['<book>', nil],
                            ])
          lambda{ 
            table.arguments_replaced({'<book>' => nil, '<qty>' => '5'})
          }.should_not raise_error
        end

      end
      
      describe "diff!" do
        it "should be added to end" do
          expected = Table.new([
            ['a', 'b'],
            ['c', 'd']
          ])
          actual = Table.new([
            ['a', 'b'],
            ['c', 'd'],
            ['e', 'f']
          ])
          expected.diff!(actual, :raise => false)
          expected.to_sexp.should == 
            [:table,
              [:row, -1, 
                [:cell, "a"], [:cell, "b"]],
              [:row, -1, 
                [:cell, "c"], [:cell, "d"]],
              [:row, -1, 
                [:plus_cell, "e"], [:plus_cell, "f"]]
            ]
        end

        it "should be added to middle" do
          expected = Table.new([
            ['a', 'b'],
            ['c', 'd']
          ])
          actual = Table.new([
            ['a', 'b'],
            ['e', 'f'],
            ['c', 'd'],
          ])
          expected.diff!(actual, :raise => false)
          expected.to_sexp.should == 
            [:table,
              [:row, -1, 
                [:cell, "a"], [:cell, "b"]],
              [:row, -1, 
                [:plus_cell, "e"], [:plus_cell, "f"]],
              [:row, -1, 
                [:cell, "c"], [:cell, "d"]],
            ]
        end

        it "should be removed from top" do
          expected = Table.new([
            ['a', 'b'],
            ['c', 'd'],
            ['e', 'f'],
          ])
          actual = [
            ['c', 'd'],
            ['e', 'f']
          ]
          expected.diff!(actual, :raise => false)
          expected.to_sexp.should == 
            [:table,
              [:row, -1, 
                [:minus_cell, "a"], [:minus_cell, "b"]],
              [:row, -1, 
                [:cell, "c"], [:cell, "d"]],
              [:row, -1, 
                [:cell, "e"], [:cell, "f"]],
            ]
        end

        it "should add and remove" do
          expected = Table.new([
            ['a', 'b'],
            ['c', 'd'],
            ['e', 'f'],
          ])
          actual = Table.new([
            ['a', 'b'],
            ['X', 'Y'],
            ['e', 'f'],
          ])
          expected.diff!(actual, :raise => false)
          expected.to_sexp.should == 
            [:table,
              [:row, -1, 
                [:cell, "a"], [:cell, "b"]],
              [:row, -1, 
                [:minus_cell, "c"], [:minus_cell, "d"]],
              [:row, -1, 
                [:plus_cell, "X"], [:plus_cell, "Y"]],
              [:row, -1, 
                [:cell, "e"], [:cell, "f"]],
            ]
        end
        
        it "should compute correct coldiff" do
          t1 = Table.new([
            ['name',  'town'],
            ['aslak', 'oslo'],
            ['joe',   'london']
          ])
          t2 = Table.new([
            ['town',   'name'],
            ['oslo',   'aslak'],
            ['london', 'joe']
          ])

          diff_with = Table.new([
            ['town',   'name',  'country', 'lisp'],
            ['oslo',   'aslak', 'no',     'false'],
            ['london', 'joe',   'uk',      'true']
          ]).hashes

          t1.diff!(diff_with, :raise => false, :coldiff => true)
          t1.to_sexp.should == [:table, 
            [:row, -1, [:cell, "name"],   [:cell, "town"],   [:plus_cell, "country"], [:plus_cell, "lisp"]], 
            [:row, -1, [:cell, "aslak"],  [:cell, "oslo"],   [:plus_cell, "no"],      [:plus_cell, "false"]], 
            [:row, -1, [:cell, "joe"],    [:cell, "london"], [:plus_cell, "uk"],      [:plus_cell, "true"]]
          ]

          t2.diff!(diff_with, :raise => false, :coldiff => true)
          t2.to_sexp.should == [:table, 
            [:row, -1, [:cell, "town"],   [:cell, "name"],   [:plus_cell, "country"], [:plus_cell, "lisp"]], 
            [:row, -1, [:cell, "oslo"],   [:cell, "aslak"],  [:plus_cell, "no"],      [:plus_cell, "false"]], 
            [:row, -1, [:cell, "london"], [:cell, "joe"],    [:plus_cell, "uk"],      [:plus_cell, "true"]]
          ]
        end

        it "should be diffable with array of hash" do
          Table.new([
            %w{a b},
            %w{c d},
            %w{e f}
          ]).diff!([
            {'a' => 'c', 'b' => 'd'},
            {'a' => 'e', 'b' => 'f'}
          ])
        end
        
        it "should keep track of offsets" do
          t1 = table(%{
            | x | y |
            | a | b |
            | c | d |
            | e | f |
            | g | h |
            | i | j |
            | k | l |
          })
          t2 = table(%{
            | x | y |
            | a | b |
            | 1 | 2 |
            | g | h |
            | i | j |
            | 3 | 4 |
            | k | l |
          })
          t1.diff!(t2, :raise => false)
          pretty(t1).should == %{
            | x | y |
            | a | b |
          - | c | d |
          - | e | f |
          + | 1 | 2 |
            | g | h |
            | i | j |
          + | 3 | 4 |
            | k | l |
          }
        end

        it "should keep track of more complex offsets" do
          t1 = table(%{
            | x | y |
            | a | b |
            | c | d |
            | e | f |
            | g | h |
            | i | j |
            | k | l |
          })
          t2 = table(%{
            | x | y |
            | 1 | 2 |
            | 3 | 4 |
            | a | b |
            | g | h |
            | 5 | 6 |
            | i | j |
            | k | l |
          })
          t1.diff!(t2, :raise => false)
          pretty(t1).should == %{
            | x | y |
          + | 1 | 2 |
          + | 3 | 4 |
            | a | b |
          - | c | d |
          - | e | f |
            | g | h |
          + | 5 | 6 |
            | i | j |
            | k | l |
          }
        end

        it "should keep track of even more complex offsets" do
          t1 = table(%{
            | 1 |
            | 2 |
            | 3 |
            | 4 |
            | 5 |
            | 6 |
            | 7 |
            | 8 |
            | 9 |
          })
          t2 = table(%{
            | A |
            | B |
            | 2 |
            | C |
            | 4 |
            | 6 |
            | 8 |
          })
          t1.diff!(t2, :raise => false)
          pretty(t1).should == %{
          - | 1 |
          + | A |
          + | B |
            | 2 |
          - | 3 |
          + | C |
            | 4 |
          - | 5 |
            | 6 |
          - | 7 |
            | 8 |
          - | 9 |
          }
        end

        it "should add surplus columns when coldiff is true" do
          t1 = table(%{
            | a     | b    |
            | one   | two  |
            | three | four |
          })
          
          t2 = table(%{
            | b     | c    | a     | d |
            | KASHA | AIIT | BOOYA | X |
            | four  | five | three | Y |
          })
          t1.diff!(t2, :raise => false, :coldiff => true)
          pretty(t1).should == %{
            | a     | b     | c    | d |
          - | one   | two   |      |   |
          + | BOOYA | KASHA | AIIT | X |
            | three | four  | five | Y |
          }
        end

        it "should not add surplus columns when coldiff is false" do
          t1 = table(%{
            | a     | b    |
            | one   | two  |
            | three | four |
          })
          
          t2 = table(%{
            | a     | b     | c    | d |
            | BOOYA | KASHA | AIIT | X |
            | three | four  | five | Y |
          })
          t1.diff!(t2, :raise => false, :coldiff => false)
          pretty(t1).should == %{
            | a     | b     | c    | d |
          - | one   | two   |      |   |
          + | BOOYA | KASHA | AIIT | X |
            | three | four  | five | Y |
          }
        end

        def table(text, file=nil, line_offset=0)
          @table_parser ||= Parser::TableParser.new
          @table_parser.parse_or_fail(text.strip, file, line_offset)
        end
        
        def pretty(table)
          io = StringIO.new

          c = Term::ANSIColor.coloring?
          Term::ANSIColor.coloring = false
          f = Formatter::Pretty.new(nil, io, {})
          f.instance_variable_set('@indent', 12)
          table.accept(f)
          Term::ANSIColor.coloring = c

          io.rewind
          s = "\n" + io.read + ("          ")
          s
        end
      end
      
      it "should convert to sexp" do
        @table.to_sexp.should == 
          [:table, 
            [:row, -1,
              [:cell, "one"], 
              [:cell, "four"],
              [:cell, "seven"]
            ],
            [:row, -1,
              [:cell, "4444"], 
              [:cell, "55555"],
              [:cell, "666666"]]]
      end
    end
  end
end
