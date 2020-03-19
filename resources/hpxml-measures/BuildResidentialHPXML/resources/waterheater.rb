class Waterheater
  def self.calc_nom_tankvol(vol, fuel, num_beds, num_baths)
    # Calculates the volume of a water heater
    if vol == Constants.Auto
      # Based on the BA HSP
      if fuel == Constants.FuelTypeElectric
        # Source: Table 5 HUD-FHA Minimum Water Heater Capacities for One- and
        # Two-Family Living Units (ASHRAE HVAC Applications 2007)
        if num_baths < 2
          if num_beds < 2
            return 20
          elsif num_beds < 3
            return 30
          else
            return 40
          end
        elsif num_baths < 3
          if num_beds < 3
            return 40
          elsif num_beds < 5
            return 50
          else
            return 66
          end
        else
          if num_beds < 4
            return 50
          elsif num_beds < 6
            return 66
          else
            return 80
          end
        end

      else # Non-electric tank WHs
        # Source: 2010 HSP Addendum
        if num_beds <= 2
          return 30
        elsif num_beds == 3
          if num_baths <= 1.5
            return 30
          else
            return 40
          end
        elsif num_beds == 4
          if num_baths <= 2.5
            return 40
          else
            return 50
          end
        else
          return 50
        end
      end
    else # user entered volume
      return vol.to_f
    end
  end

  def self.calc_ef(ef, vol, fuel)
    # Calculate the energy factor as a function of the tank volume and fuel type
    if ef == Constants.Auto
      if (fuel == Constants.FuelTypePropane) || (fuel == Constants.FuelTypeGas)
        return 0.67 - (0.0019 * vol)
      elsif fuel == Constants.FuelTypeElectric
        return 0.97 - (0.00132 * vol)
      else
        return 0.59 - (0.0019 * vol)
      end
    else # user input energy factor
      return ef.to_f
    end
  end
end
