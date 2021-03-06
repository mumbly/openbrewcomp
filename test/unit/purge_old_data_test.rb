# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + '/../test_helper'

class PurgeOldDataTest < ActiveSupport::TestCase
  # PurgeOldData#zap uses a DB transaction for its processing so
  # transactional fixtures must be disabled for this test suite.
  self.use_transactional_fixtures = false
  
  def test_initialize
    tables_to_purge = PurgeOldData.new
    assert tables_to_purge.valid?
  end

  def test_unknown_table_as_symbol
    tables_to_purge = PurgeOldData.new(:unknown)
    assert !tables_to_purge.valid?
    assert_equal [ 'Unknown or invalid table: unknown' ], tables_to_purge.errors
  end

  def test_unknown_table
    tables_to_purge = PurgeOldData.new('unknown')
    assert !tables_to_purge.valid?
    assert_equal [ 'Unknown or invalid table: unknown' ], tables_to_purge.errors
  end

  def test_unknown_tables
    tables_to_purge = PurgeOldData.new(['unknown1', 'unknown2'])
    assert !tables_to_purge.valid?
    assert_equal [ 'Unknown or invalid tables: unknown1 and unknown2' ], tables_to_purge.errors
  end

  def test_zap
    cleared_tables = %w(entries flights entries_flights scores judgings judging_sessions
                        category_preferences time_availabilities)
    starting_table_sizes = fixture_table_names.inject({}){ |hash,name|
      hash[name] = name.classify.constantize.count
      hash
    }
    ending_table_sizes = starting_table_sizes.merge(cleared_tables.inject({}){ |hash,name|
      hash[name] = 0
      hash
    })

    # Verify the starting table sizes
    starting_table_sizes.each do |name,size|
      assert size > 0, name
    end

    # Assign some staff points
    Controller.admin_view = true  # must be done as admin
    unless (Judge.sum(:staff_points) || 0) > 0
      j1 = judges(:recognized_judge)
      assert_not_nil j1
      j1.staff_points = 0.5
      assert j1.save
      j2 = judges(:experienced_judge)
      assert_not_nil j2
      j2.staff_points = 0.5
      assert j2.save
    end
    assert Judge.sum(:staff_points) > 0
    
    tables_to_purge = PurgeOldData.new
    tables_to_purge.zap

    # Verify the ending table sizes
    ending_table_sizes.each do |name,size|
      assert_equal size, name.classify.constantize.count, "Table #{name}"
    end

    # Verify that no organizer is specified and no staff_points are allocated
    assert_nil Judge.organizer
    assert 0, (Judge.sum(:staff_points) || 0)
  end

  def test_zap_with_additional_tables
    cleared_tables = %w(entries flights entries_flights scores judgings judging_sessions
                        category_preferences time_availabilities entrants judges)
    starting_table_sizes = fixture_table_names.inject({}){ |hash,name|
      hash[name] = name.classify.constantize.count
      hash
    }
    ending_table_sizes = starting_table_sizes.merge(cleared_tables.inject({}){ |hash,name|
      hash[name] = 0
      hash
    })

    # Verify the starting table sizes
    starting_table_sizes.each do |name,size|
      assert size > 0, name
    end

    tables_to_purge = PurgeOldData.new(%w(entrants judges))
    tables_to_purge.zap

    # Verify the ending table sizes
    ending_table_sizes.each do |name,size|
      assert_equal size, name.classify.constantize.count, "Table #{name}"
    end
  end

  def test_zap_should_not_delete_admin_users
    cleared_tables = %w(entries flights entries_flights scores judgings judging_sessions
                        category_preferences time_availabilities entrants judges users
                        roles_users passwords)
    starting_table_sizes = fixture_table_names.inject({}){ |hash,name|
      hash[name] = name.classify.constantize.count
      hash
    }
    ending_table_sizes = starting_table_sizes.merge(cleared_tables.inject({}){ |hash,name|
      hash[name] = case name
                   when 'users'
                     User.admins.count
                   when 'roles_users'
                     RolesUser.all.select{|r| User.admins.collect(&:id).include?(r.user_id)}.length
                   else
                     0
                   end
      hash
    })

    # Verify the starting table sizes
    starting_table_sizes.each do |name,size|
      assert size > 0, name
    end

    tables_to_purge = PurgeOldData.new(%w(entrants judges users))
    tables_to_purge.zap

    # Verify the ending table sizes
    ending_table_sizes.each do |name,size|
      assert_equal size, name.classify.constantize.count, "Table #{name}"
    end
  end

  def test_zap_should_not_delete_judges_if_not_included_in_list_of_tables
    cleared_tables = %w(entries flights entries_flights scores judgings judging_sessions
                        category_preferences time_availabilities entrants users
                        roles_users passwords)
    starting_table_sizes = fixture_table_names.inject({}){ |hash,name|
      hash[name] = name.classify.constantize.count
      hash
    }
    ending_table_sizes = starting_table_sizes.merge(cleared_tables.inject({}){ |hash,name|
      hash[name] = case name
                   when 'users'
                     User.admins.count
                   when 'roles_users'
                     RolesUser.all.select{|r| User.admins.collect(&:id).include?(r.user_id)}.length
                   else
                     0
                   end
      hash
    })

    # Verify the starting table sizes
    starting_table_sizes.each do |name,size|
      assert size > 0, name
    end

    tables_to_purge = PurgeOldData.new(%w(entrants users))
    tables_to_purge.zap

    # Verify the ending table sizes
    ending_table_sizes.each do |name,size|
      assert_equal size, name.classify.constantize.count, "Table #{name}"
    end
  end

end
